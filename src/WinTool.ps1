$ErrorActionPreference = 'Stop'
$logPath = if ($env:WINTOOL_LOG_PATH) {
    $env:WINTOOL_LOG_PATH
} else {
    Join-Path (Split-Path -Parent $PSScriptRoot) 'WinTool.txt'
}

function Write-SessionLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $logPath -Value "$timestamp - $Message" -Encoding UTF8
}

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

Write-SessionLog 'WinTool baslatildi.'

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
        & winget show --id $Application.Id --source msstore --exact --accept-source-agreements --disable-interactivity 2>$null
    } else {
        & winget show --id $Application.Id --exact --accept-source-agreements --disable-interactivity 2>$null
    }

    $sizePattern = '(?i)(Installer Size|Download Size|Yükleyici Boyutu|İndirme Boyutu)\s*:\s*([\d.,]+)\s*(KB|MB|GB)'
    foreach ($line in $showOutput) {
        if ($line -match $sizePattern) {
            $sizeText = $matches[2]
            if ($sizeText.Contains(',') -and $sizeText.Contains('.')) {
                $sizeText = $sizeText.Replace('.', '').Replace(',', '.')
            } else {
                $sizeText = $sizeText.Replace(',', '.')
            }
            $size = [double]::Parse($sizeText, [Globalization.CultureInfo]::InvariantCulture)
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

function Get-ApplicationSizeReport {
    param(
        [Parameter(Mandatory = $true)]
        $Applications
    )

    $sizes = foreach ($application in $Applications) {
        $source = if ($application.Source) { $application.Source } else { 'winget' }
        $bytes = Get-InstallerSizeBytes -Application $application -Source $source
        if ($bytes -eq 0) {
            Write-SessionLog "$($application.Name) için winget paket boyutu alınamadı; toplam ilerleme yaklaşık olabilir."
        }
        [long]$bytes
    }
    return @($sizes)
}

function Show-DownloadProgress {
    param(
        [Parameter(Mandatory = $true)]
        [long]$DownloadedBytes,
        [Parameter(Mandatory = $true)]
        [long]$TotalBytes,
        [Parameter(Mandatory = $true)]
        [string]$ApplicationName,
        [Parameter(Mandatory = $true)]
        [long]$ApplicationBytes,
        [Parameter(Mandatory = $true)]
        [long]$ApplicationTotalBytes,
        [Parameter(Mandatory = $true)]
        [int]$CompletedCount,
        [Parameter(Mandatory = $true)]
        [int]$TotalCount
    )

    $totalPercent = if ($TotalBytes -gt 0) {
        [math]::Min(100, [math]::Floor(($DownloadedBytes / $TotalBytes) * 100))
    } else {
        [math]::Floor(($CompletedCount / $TotalCount) * 100)
    }
    $applicationPercent = if ($ApplicationTotalBytes -gt 0) {
        [math]::Min(100, [math]::Floor(($ApplicationBytes / $ApplicationTotalBytes) * 100))
    } else {
        0
    }
    $downloadedMB = [math]::Round($DownloadedBytes / 1MB, 1)
    $totalMB = [math]::Round($TotalBytes / 1MB, 1)
    $totalLabel = if ($TotalBytes -gt 0) { "$totalMB MB" } else { 'boyut bilinmiyor' }
    $applicationMB = [math]::Round($ApplicationBytes / 1MB, 1)
    $applicationTotalLabel = if ($ApplicationTotalBytes -gt 0) {
        "$([math]::Round($ApplicationTotalBytes / 1MB, 1)) MB"
    } else {
        'boyut bilinmiyor'
    }
    Write-Progress -Id 1 -Activity 'Toplam indirme' -Status "$CompletedCount/$TotalCount uygulama, $downloadedMB / $totalLabel" -PercentComplete $totalPercent
    Write-Progress -Id 2 -Activity "İndiriliyor: $ApplicationName" -Status "$applicationMB / $applicationTotalLabel" -PercentComplete $applicationPercent
}

function Get-DirectoryFileBytes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $sum = (Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
    if ($sum) {
        return [long]$sum
    }
    return [long]0
}

function Start-WingetDownload {
    param(
        [Parameter(Mandatory = $true)]
        $Application,
        [Parameter(Mandatory = $true)]
        [string]$DownloadPath,
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    $outputPath = Join-Path ([IO.Path]::GetTempPath()) ("wintool-" + [guid]::NewGuid().ToString() + '.out')
    $errorPath = Join-Path ([IO.Path]::GetTempPath()) ("wintool-" + [guid]::NewGuid().ToString() + '.err')
    # Do not add manual quoting to the download path; pass it as a plain argument
    $downloadDirArg = $DownloadPath
    $arguments = if ($Source -eq 'msstore') {
        @('download', '--id', $Application.Id, '--source', 'msstore', '--skip-license', '--download-directory', $downloadDirArg)
    } else {
        @('download', '--id', $Application.Id, '--exact', '--download-directory', $downloadDirArg, '--accept-source-agreements', '--accept-package-agreements')
    }
    # Start winget without opening a new visible window when possible and capture output
    $process = Start-Process -FilePath 'winget' -ArgumentList $arguments `
        -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath -PassThru -NoNewWindow -WindowStyle Hidden
    return [pscustomobject]@{
        Process = $process
        OutputPath = $outputPath
        ErrorPath = $errorPath
    }
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
    $installerSizes = Get-ApplicationSizeReport -Applications $selection
    $totalBytes = ($installerSizes | Measure-Object -Sum).Sum
    $hasUnknownSize = @($installerSizes | Where-Object { $_ -le 0 }).Count -gt 0
    if ($hasUnknownSize -or -not $totalBytes) {
        $totalBytes = 0
    }
    $completedCount = 0
    for ($index = 0; $index -lt $selection.Count; $index++) {
        $application = $selection[$index]
        $source = if ($application.Source) { $application.Source } else { 'winget' }
        $applicationTotalBytes = [long]$installerSizes[$index]
        $applicationStartBytes = Get-DirectoryFileBytes -Path $downloadPath
        $download = Start-WingetDownload -Application $application -DownloadPath $downloadPath -Source $source
        while (-not $download.Process.HasExited) {
            $currentBytes = Get-DirectoryFileBytes -Path $downloadPath
            $downloadedBytes = [math]::Max(0, $currentBytes - $initialBytes)
            $applicationBytes = [math]::Max(0, $currentBytes - $applicationStartBytes)
            Show-DownloadProgress -DownloadedBytes $downloadedBytes -TotalBytes $totalBytes `
                -ApplicationName $application.Name -ApplicationBytes $applicationBytes `
                -ApplicationTotalBytes $applicationTotalBytes -CompletedCount $completedCount -TotalCount $selection.Count
            Start-Sleep -Milliseconds 250
        }
        $currentBytes = Get-DirectoryFileBytes -Path $downloadPath
        $downloadedBytes = [math]::Max(0, $currentBytes - $initialBytes)
        $applicationBytes = [math]::Max(0, $currentBytes - $applicationStartBytes)
        if ($download.Process.ExitCode -ne 0) {
            Write-Host "`nİndirme başarısız oldu." -ForegroundColor Red
            Write-SessionLog "$($application.Name) indirme başarısız oldu (kod: $($download.Process.ExitCode))."
        } else {
            $completedCount++
            Show-DownloadProgress -DownloadedBytes $downloadedBytes -TotalBytes $totalBytes `
                -ApplicationName $application.Name -ApplicationBytes $applicationBytes `
                -ApplicationTotalBytes $applicationTotalBytes -CompletedCount $completedCount -TotalCount $selection.Count
            Write-SessionLog "$($application.Name) indirildi."
        }
        Remove-Item -LiteralPath $download.OutputPath, $download.ErrorPath -Force -ErrorAction SilentlyContinue
    }
    Write-Progress -Id 2 -Activity 'İndirme tamamlandı' -Completed
    Write-Progress -Id 1 -Activity 'Toplam indirme' -Completed
    $finalBytes = (Get-ChildItem -LiteralPath $downloadPath -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
    if (-not $finalBytes) {
        $finalBytes = 0
    }
    $downloadedFinalBytes = [math]::Max(0, $finalBytes - $initialBytes)
    Write-Host "`nToplam indirilen boyut: $([math]::Round($downloadedFinalBytes / 1MB, 1)) MB"
    Write-SessionLog "İndirme tamamlandı. Toplam indirilen boyut: $([math]::Round($downloadedFinalBytes / 1MB, 1)) MB."
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

    $compareChoice = (Read-Host 'Hash karşılaştırması yapmak istiyor musunuz? (E/H)').Trim()
    if ($compareChoice -notin @('E', 'e')) {
        return
    }

    Write-Host ''
    Write-Host 'Karşılaştırılacak algoritmayı seçin:'
    Write-Host '1) MD5'
    Write-Host '2) SHA1'
    Write-Host '3) SHA256'
    $algorithmChoice = (Read-Host 'Seçiminiz').Trim()
    $algorithm = switch ($algorithmChoice) {
        '1' { 'MD5' }
        '2' { 'SHA1' }
        '3' { 'SHA256' }
        default { $null }
    }

    if (-not $algorithm) {
        Write-Host 'Geçersiz algoritma seçimi.' -ForegroundColor Yellow
        Read-Host 'Ana menüye dönmek için Enter'
        return
    }

    $expectedHash = (Read-Host "$algorithm hash değerini girin").Trim()
    $actualHash = ($hashes | Where-Object { $_.Algoritma -eq $algorithm }).Hash
    if ($actualHash.Equals($expectedHash, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Host 'Hash değerleri eşleşiyor.' -ForegroundColor Green
    } else {
        Write-Host 'Hash değerleri eşleşmiyor.' -ForegroundColor Red
        Write-Host "Beklenen: $expectedHash"
        Write-Host "Dosya:     $actualHash"
    }
    Read-Host 'Ana menüye dönmek için Enter'
}

Test-Winget
while ($true) {
    Clear-Host
    Write-Host 'WinTool PS' -ForegroundColor Cyan
    Write-Host '1) Uygulama indir'
    Write-Host '2) Hash al'
    Write-Host '3) Çıkış'
    switch ((Read-Host 'Seçiminiz').Trim()) {
        '1' { Download-Applications }
        '2' { Get-Hashes }
        '3' { Write-SessionLog 'WinTool menuden kapatildi.'; return }
        default { Write-Host 'Geçersiz seçim.' -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
    }
}
