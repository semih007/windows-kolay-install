# Teknik Mimari ve Sistem Şeması

## 1. Teknoloji Yığını
- **Çalışma Ortamı:** Windows PowerShell 5.1 & PowerShell Core 7+
- **Kullanılan Yerel Komutlar:**
  - Paket İndirme: `winget download`
  - Hash Alma: `Get-FileHash -Algorithm <ALG>`
  - Dizin Yönetimi: `New-Item`, `Test-Path`, `Join-Path`
  - Ekran / Giriş: `Clear-Host`, `Write-Host`, `Read-Host`

## 2. Proje Dosya Yapısı
```text
wintool-ps/
├── WinTool.ps1          # Ana çalıştırılabilir PowerShell betiği
├── Config.ps1           # Statik uygulama listesi (Winget ID ve İsimler)
├── HAKKINDA.md
├── TEKNIK_MIMARI.md
└── GOREV_LISTESI.md