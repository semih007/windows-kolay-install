$ErrorActionPreference = 'Stop'
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
        Write-Host ("  {0}) {1} [{2}; kaynak: {3}]" -f $number, $Applications[$index].Name, $Applications[$index].Id, $source)
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

function Install-Applications {
    Show-AppList
    $selection = Read-AppSelection
    if ($selection.Count -eq 0) {
        return
    }

    foreach ($application in $selection) {
        $source = if ($application.Source) { $application.Source } else { 'winget' }
        Write-Host ("`nYükleniyor: {0} ({1}; kaynak: {2})" -f $application.Name, $application.Id, $source) -ForegroundColor Cyan
        if ($source -eq 'msstore') {
            & winget install --id $application.Id --source msstore --accept-source-agreements
        } else {
            & winget install $application.Id --exact --accept-source-agreements
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host ("BAŞARISIZ: {0}. Paket kimliği bulunamadı veya yükleme başarısız oldu." -f $application.Name) -ForegroundColor Red
        } else {
            Write-Host ("Tamamlandı: {0}" -f $application.Name) -ForegroundColor Green
        }
    }
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
    Write-Host '1) Uygulama yükle'
    Write-Host '2) Hash al'
    Write-Host '0) Çıkış'
    switch ((Read-Host 'Seçiminiz').Trim()) {
        '1' { Install-Applications }
        '2' { Get-Hashes }
        '0' { return }
        default { Write-Host 'Geçersiz seçim.' -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
    }
}
