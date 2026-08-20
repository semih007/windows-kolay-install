# Proje: WinTool PS (PowerShell Windows Yardımcı Aracı)

## 1. Proje Amacı
Bu proje, Chris Titus Tech'in "WinUtil" aracına benzer mantıkla çalışan, Windows sistemlerde ek hiçbir yazılım/çalışma ortamı (Python, Node.js vb.) gerektirmeyen, doğrudan yerel PowerShell ve Winget altyapısını kullanan interaktif bir CLI / TUI yönetim aracıdır.

## 2. Temel Fonksiyonlar
- **Uygulama İndirici:** Statik olarak tanımlanmış yazılımların kurulum dosyalarını `winget download` komutuyla Masaüstü'ndeki `app` klasörüne çeker. Tekli veya çoklu (virgülle ayrılmış) seçimi destekler.
- **Hash Hesaplayıcı:** Kullanıcının girdiği bir dosya yolunu alarak `Get-FileHash` ile MD5, SHA1 ve SHA256 değerlerini hesaplayıp ekrana formatlı olarak basar.

## 3. Temel Kurallar ve Kısıtlamalar
- Sadece saf **PowerShell 5.1+ / PowerShell 7+** kullanılacaktır.
- Harici dil/kütüphane bağımlılığı OLMAYACAKTIR.
- Doğrudan bir `.ps1` dosyası olarak ya da tek satırlık PowerShell komutuyla çalıştırılabilir mimaride olmalıdır.
- Winget ve dosya erişimi için gerekli yetki/hata kontrolleri bulunmalıdır.