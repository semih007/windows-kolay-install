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
```

## 3. Statik Winget Uygulama Listesi

`Config.ps1` içindeki liste, görünen adları Winget paket kimlikleriyle eşler:

| Görünen ad | Winget ID |
|---|---|
| 7-Zip | `7zip.7zip` |
| Google Chrome | `Google.Chrome` |
| Brave | `Brave.Brave` |
| Revo Uninstaller | `RevoUninstaller.RevoUninstaller` |
| LocalSend | `LocalSend.LocalSend` |
| Display Driver Uninstaller (DDU) | `Wagnardsoft.DisplayDriverUninstaller` |
| Proton Pass | `ProtonTechnologies.ProtonPass` |
| Ente Auth | `Ente.Auth` |

Liste dinamik değildir; yeni uygulama eklemek için yalnızca `Config.ps1` güncellenir.
