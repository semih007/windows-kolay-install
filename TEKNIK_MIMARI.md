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

## 3. Uygulama Paket Listesi

`Config.ps1` içindeki liste, uygulama adlarını kaynaklara göre paket adları ve
kimlikleriyle eşler.

### Winget paketleri

| Uygulama adı                     | Paket adı              |
|----------------------------------------------------------------------------|
| 7-Zip                            | `7zip.7zip` |
| Google Chrome                    | `Google.Chrome`  |
| Brave (Winget)                   | `Brave.Brave`   |
| Revo Uninstaller (Winget)        | `RevoUninstaller.RevoUninstaller` |
| LocalSend                        | `LocalSend.LocalSend` |
| Ventoy                           | `Ventoy.Ventoy` |
| Display Driver Uninstaller (DDU) | `Wagnardsoft.DisplayDriverUninstaller` |
| CPU-Z                            | `CPUID.CPU-Z` |
| Proton Pass                      | `Proton.ProtonPass` |
| Google Quick Share               | `Google.QuickShare` |
| Ente Auth                        | `ente-io.auth-desktop` |

### Microsoft Store paketleri

| Uygulama adı                       | Paket ID |
|------------------------------------|------------------|
| Brave (Microsoft Store)            | `XP8C9QZMS2PC1T` |
| Revo Uninstaller (Microsoft Store) | `XPFFVD4CMXN8VN` |

Liste dinamik değildir; yeni uygulama eklemek için yalnızca `Config.ps1` güncellenir.
