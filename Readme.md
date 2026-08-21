# Proje: WinTool PS (PowerShell Windows Yardımcı Aracı)

## 1. Proje Amacı
Bu proje, Chris Titus Tech'in "WinUtil" aracına benzer mantıkla çalışan, Windows sistemlerde ek hiçbir yazılım/çalışma ortamı (Python, Node.js vb.) gerektirmeyen, doğrudan yerel PowerShell ve Winget altyapısını kullanan interaktif bir CLI / TUI yönetim aracıdır.

## 2. Temel Fonksiyonlar
- **Uygulama İndirici:** Statik olarak tanımlanmış yazılımların kurulum dosyalarını `winget download` komutuyla Masaüstü'ndeki `App` klasörüne çeker. `App` klasörü zaten varsa `App-gün-ay-yıl` adlı klasör oluşturup onu kullanır. Çoklu indirmelerde toplam MB, yüzde ve tamamlanan uygulama sayısını tek satırda gösterir.
- **Hash Hesaplayıcı:** Kullanıcının girdiği bir dosya yolunu alarak `Get-FileHash` ile MD5, SHA1 ve SHA256 değerlerini hesaplayıp ekrana formatlı olarak basar.

## Çalıştırma

PowerShell ile proje klasöründe `.\src\WinTool.ps1` komutunu çalıştırın. Uygulama listesi `src\Config.ps1` içinde statik olarak tutulur; seçim `1,3,4` biçiminde çoklu yapılabilir. Başarısız Winget indirmeleri ekranda açıkça raporlanır.

Programı terminalden çalıştırmak yerine proje klasöründeki `WinTool.cmd` dosyasına çift tıklayarak başlatabilirsiniz. Bu dosya, `src` klasöründeki `WinTool.ps1` betiğini otomatik olarak çalıştırır.

Tüm çalıştırmalar proje kökündeki `WinTool.txt` dosyasına tarih damgasıyla eklenir; her çalıştırmada yeni bir log dosyası oluşturulmaz.
Microsoft Store kaynaklı uygulamalar (`msstore`) de `winget download --source msstore --skip-license` komutuyla indirilebilir.

## 3. Temel Kurallar ve Kısıtlamalar
- Sadece saf **PowerShell 5.1+ / PowerShell 7+** kullanılacaktır.
- Harici dil/kütüphane bağımlılığı OLMAYACAKTIR.
- Doğrudan bir `.ps1` dosyası olarak ya da tek satırlık PowerShell komutuyla çalıştırılabilir mimaride olmalıdır.
- Winget ve dosya erişimi için gerekli yetki/hata kontrolleri bulunmalıdır.
