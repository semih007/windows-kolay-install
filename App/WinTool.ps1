$ErrorActionPreference = 'Stop'

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdministrator) {
    $hostExecutable = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
    Start-Process -FilePath $hostExecutable `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"") `
        -Verb RunAs
    exit
}

$configPath = Join-Path $PSScriptRoot 'Config.ps1'

if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Config.ps1 bulunamadı: $configPath"
}

$Applications = @(. $configPath)

function Test-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget bulunamadı. Windows App Installer paketini yükleyin ve tekrar deneyin.'
    }
}

function Show-AppList {
    Write-Host ''
    Write-Host 'Yüklenebilir uygulamalar:' -ForegroundColor Cyan
    for ($index = 0; $index -lt $Applications.Count; $index++) {
        $number = $index + 1
        $source = if ($Applications[$index].Source) { $Applications[$index].Source } else { 'winget' }
        $sourceLabel = if ($source -eq 'msstore') { 'ms store' } else { $source }
        Write-Host ("  {0}) {1} ({2})" -f $number, $Applications[$index].Name, $sourceLabel)
    }
    Write-Host ''
}

function Read-AppSelection {
    while ($true) {
        $inputText = (Read-Host 'Seçim (örn. 1,3,4; iptal için 0)').Trim()
        if ($inputText -eq '0') {
            return @()
        }

        $tokens = $inputText -split ',' | ForEach-Object { $_.Trim() }
        $numbers = @()
        $valid = $true
        foreach ($token in $tokens) {
            $number = 0
            if (-not [int]::TryParse($token, [ref]$number) -or $number -lt 1 -or $number -gt $Applications.Count) {
                $valid = $false
                break
            }
            $numbers += $number
        }

        if ($valid -and $numbers.Count -gt 0) {
            return @($numbers | Select-Object -Unique | ForEach-Object { $Applications[$_ - 1] })
        }
        Write-Host 'Geçersiz seçim. Virgülle ayrılmış numaralar girin.' -ForegroundColor Yellow
    }
}

function Get-InstallerSizeBytes {
    param(
        [Parameter(Mandatory = $true)]
        $Application,
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    $showOutput = if ($Source -eq 'msstore') {
        & winget show --id $Application.Id --source msstore --exact --accept-source-agreements 2>$null
    } else {
        & winget show --id $Application.Id --exact --accept-source-agreements 2>$null
    }

    $sizePattern = '(?i)(Installer Size|Yükleyici Boyutu)\s*:\s*([\d.,]+)\s*(KB|MB|GB)'
    foreach ($line in $showOutput) {
        if ($line -match $sizePattern) {
            $size = [double]::Parse($matches[2].Replace(',', '.'), [Globalization.CultureInfo]::InvariantCulture)
            $multiplier = switch ($matches[3].ToUpperInvariant()) {
                'KB' { 1KB }
                'MB' { 1MB }
                'GB' { 1GB }
            }
            return [math]::Round($size * $multiplier)
        }
    }

    return 0
}

function Show-DownloadProgress {
    param(
        [Parameter(Mandatory = $true)]
        [long]$DownloadedBytes,
        [Parameter(Mandatory = $true)]
        [long]$TotalBytes,
        [Parameter(Mandatory = $true)]
        [int]$CompletedCount,
        [Parameter(Mandatory = $true)]
        [int]$TotalCount
    )

    $percent = if ($TotalBytes -gt 0) {
        [math]::Min(100, [math]::Floor(($DownloadedBytes / $TotalBytes) * 100))
    } else {
        [math]::Floor(($CompletedCount / $TotalCount) * 100)
    }
    $downloadedMB = [math]::Round($DownloadedBytes / 1MB, 1)
    $totalMB = [math]::Round($TotalBytes / 1MB, 1)
    $barLength = 20
    $filledLength = [math]::Floor(($percent / 100) * $barLength)
    $bar = ('█' * $filledLength) + ('░' * ($barLength - $filledLength))
    Write-Host "`rToplam ilerleme: [$bar] $percent% $CompletedCount/$TotalCount indirme tamamlandı ($downloadedMB / $totalMB MB)" -NoNewline
}

function Download-Applications {
    Show-AppList
    $selection = Read-AppSelection
    if ($selection.Count -eq 0) {
        return
    }

    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $appPath = Join-Path $desktopPath 'App'
    if (Test-Path -LiteralPath $appPath -PathType Container) {
        $dateLabel = Get-Date -Format 'dd-MM-yyyy'
        $downloadPath = Join-Path $desktopPath "App-$dateLabel"
    } else {
        $downloadPath = $appPath
    }
    New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null

    $initialBytes = (Get-ChildItem -LiteralPath $downloadPath -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
    if (-not $initialBytes) {
        $initialBytes = 0
    }
    $installerSizes = @($selection | ForEach-Object {
        $source = if ($_.Source) { $_.Source } else { 'winget' }
        Get-InstallerSizeBytes -Application $_ -Source $source
    })
    $totalBytes = ($installerSizes | Measure-Object -Sum).Sum
    if (-not $totalBytes) {
        $totalBytes = 0
    }
    $completedCount = 0

    foreach ($application in $selection) {
        $source = if ($application.Source) { $application.Source } else { 'winget' }
        Write-Host ''
        if ($source -eq 'msstore') {
            & winget download --id $application.Id --source msstore --download-directory $downloadPath --accept-source-agreements --accept-package-agreements 2>&1 |
                ForEach-Object {
                    $currentBytes = (Get-ChildItem -LiteralPath $downloadPath -File -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum).Sum
                    Show-DownloadProgress -DownloadedBytes ([math]::Max(0, $currentBytes - $initialBytes)) -TotalBytes $totalBytes -CompletedCount $completedCount -TotalCount $selection.Count
                }
        } else {
            & winget download --id $application.Id --exact --download-directory $downloadPath --accept-source-agreements --accept-package-agreements 2>&1 |
                ForEach-Object {
                    $currentBytes = (Get-ChildItem -LiteralPath $downloadPath -File -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum).Sum
                    Show-DownloadProgress -DownloadedBytes ([math]::Max(0, $currentBytes - $initialBytes)) -TotalBytes $totalBytes -CompletedCount $completedCount -TotalCount $selection.Count
                }
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "`nİndirme başarısız oldu." -ForegroundColor Red
        } else {
            $completedCount++
            $currentBytes = (Get-ChildItem -LiteralPath $downloadPath -File -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
            Show-DownloadProgress -DownloadedBytes ([math]::Max(0, $currentBytes - $initialBytes)) -TotalBytes $totalBytes -CompletedCount $completedCount -TotalCount $selection.Count
        }
    }
    Write-Host ''
    Read-Host "`nAna menüye dönmek için Enter"
}

function Get-Hashes {
    $path = (Read-Host 'Dosya yolunu girin veya dosyayı sürükleyin').Trim().Trim('"')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Host 'Dosya bulunamadı.' -ForegroundColor Red
        Read-Host 'Ana menüye dönmek için Enter'
        return
    }

    $hashes = foreach ($algorithm in @('MD5', 'SHA1', 'SHA256')) {
        $hash = Get-FileHash -LiteralPath $path -Algorithm $algorithm
        [pscustomobject]@{ Algoritma = $hash.Algorithm; Hash = $hash.Hash }
    }
    $hashes | Format-Table -AutoSize
    Read-Host 'Ana menüye dönmek için Enter'
}

Test-Winget
while ($true) {
    Clear-Host
    Write-Host 'WinTool PS' -ForegroundColor Cyan
    Write-Host '1) Uygulama indir'
    Write-Host '2) Hash al'
    Write-Host '0) Çıkış'
    switch ((Read-Host 'Seçiminiz').Trim()) {
        '1' { Download-Applications }
        '2' { Get-Hashes }
        '0' { return }
        default { Write-Host 'Geçersiz seçim.' -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
    }
}
