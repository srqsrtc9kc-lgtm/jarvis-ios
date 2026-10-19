# Windows 11 ile iPhone'a kişisel kurulum

Bu yol ücretli Developer Program veya TestFlight kullanmaz. GitHub macOS üzerinde
gerçek iPhoneOS arm64 Release uygulamasını imzasız derler; Sideloadly Windows'ta
kendi Apple hesabınla yeniden imzalar. IPA'nın derlenmesi, telefona başarıyla
kurulduğunu veya ses/AI özelliklerinin cihazda çalıştığını kanıtlamaz.

## İndir ve kur

Ücretsiz geliştirici kaydın henüz yoksa [Apple Developer hesabında](https://developer.apple.com/account/)
kendi Apple hesabınla giriş yapıp Apple Developer Agreement'ı kabul et.
Ücretli Developer Program üyeliği satın almak bu kişisel kurulum yolunun adımı değildir.

1. [GitHub Actions](https://github.com/srqsrtc9kc-lgtm/jarvis-ios/actions/workflows/ios-compile.yml)
   sayfasında en yeni **başarılı** çalışmayı aç. Gerekirse GitHub hesabınla giriş yap.
   Sayfanın altındaki **Artifacts > JARVIS-iPhoneOS-arm64-unsigned** paketini indir.
   ZIP'i çıkar; Sideloadly'ye verilecek dosya **JARVIS-unsigned.ipa**'dır.
   Test sonuçları artifact'ı ve kaynak kod ZIP'i kurulabilir uygulama değildir.
   Paket 14 gün saklanır; süresi dolarsa **Run workflow** ile yeniden üret.
2. [Sideloadly resmi sitesinden](https://sideloadly.io/) Windows 64-bit sürümünü kur.
   Aynı sayfadaki Windows yönergelerine göre web iTunes ve iCloud sürümlerini kur;
   Sideloadly, Microsoft Store sürümleri yerine bu sürümleri istiyor.
3. iPhone'u USB ile bağla, kilidini aç ve **Bu Bilgisayara Güven** onayını ver.
   Sideloadly'de doğru cihazı seç, IPA'yı bırak ve kendi Apple hesabınla **Start**'a bas.
   Parolanı ve 2FA kodunu yalnızca Sideloadly/Apple'ın yerel ekranlarında gir;
   sohbete, kaynak koda veya GitHub Secrets'a ekleme.
4. iPhone'da **Ayarlar > Gizlilik ve Güvenlik > Geliştirici Modu**'nu aç,
   yeniden başlat ve açılışta etkinleştirmeyi onayla. Menü ilk eşleme/kurulum
   girişiminden önce görünmeyebilir.
5. **Ayarlar > Genel > VPN ve Aygıt Yönetimi** bölümünde kendi geliştirici
   hesabına güven. Bu, USB bilgisayar güveninden ayrı bir onaydır.
6. JARVIS'i aç. Ses kullanacaksan mikrofon ve konuşma tanıma izinlerini ver.
   Önce yazılı bir çalışma açıp kaydet; ardından ses, AI ve bildirimleri
   [cihaz kontrol listesiyle](CIHAZ-TESTI.md) ayrı ayrı dene.

## Ücretsiz hesabın sınırları

Apple Personal Team: en fazla 10 App ID, 3 cihaz, cihaz başına 3 uygulama;
provisioning profili 7 gün geçerlidir. Uygulamayı **7 gün dolmadan yeniden imzala**.
Aynı Apple hesabını ve aynı uygulama kimliğini kullan; uygulamayı silmeden yenile.
Önemli kayıtları JARVIS Ayarlar'dan dışa aktar. Sideloadly'nin otomatik yenilemesi
için bilgisayar açık, daemon çalışır ve iPhone USB veya yapılandırılmış Wi-Fi
üzerinden erişilebilir olmalıdır; telefon tek başına yenileme yapmaz.

## iOS, Türkçe ve bağımlılıklar

- Uygulamanın minimum sürümü **iOS 26.0**; derleme Xcode 26.6 ile yapılır.
  Sideloadly'de minimum sürümü düşürmek bu API gereksinimini ortadan kaldırmaz.
- Apple Intelligence/Türkçe model desteği ile Türkçe ses tanıma ayrı koşullardır.
  Türkçe Apple Intelligence için iOS 26.1 veya sonrası gerekir; cihaz ve Siri
  dilini aynı desteklenen dile ayarla, Apple Intelligence'ı etkinleştir ve model
  indirmesinin tamamlanmasını bekle. Bu, uygulamanın 26.0 derleme minimumundan ayrıdır.
  Uygulama model kullanılabilirliğini ve `supportsLocale(tr_TR)` sonucunu kontrol
  eder. Model hazır değilse sabit, etiketli rehberli egzersizler sunar.
- Mikrofon yalnızca Türkçe `supportsOnDeviceRecognition` ve kullanılabilirlik
  kontrolü geçerse başlar. Yerel Türkçe tanıma yoksa yazılı giriş kullanılır;
  bulut ses tanımaya otomatik geçilmez. Başarılı derleme bu cihaz desteğini kanıtlamaz.
- Harici Swift paketi yoktur. FoundationModels, Speech, AVFoundation ve diğer
  kullanılan framework'ler Apple SDK'sındandır. Kaynakta özel adapter veya özel
  entitlement isteği yoktur; kişisel imzalama ve model erişimi cihazda ayrıca denenir.

## Paketin doğrulanması

Artifact'ta kaynak commit'i ve Xcode/SDK sürümü `build-info.txt`, paket kontrolü
`validation.txt`, SHA-256 özeti `JARVIS-unsigned.ipa.sha256` dosyasındadır.
Windows PowerShell'de `Get-FileHash .\JARVIS-unsigned.ipa -Algorithm SHA256`
sonucunu bu özetle karşılaştırabilirsin. Doğrulayıcı gerçek Mach-O iOS platformunu,
arm64 mimarisini, Info.plist'i ve imza/profil bulunmamasını kontrol eder.
İmzasız IPA doğrudan telefonda açılamaz; Sideloadly imzalaması gerekir.

## Birincil kaynaklar

- [Apple: Personal Team sınırları](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Apple: Geliştirici Modu](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
- [Apple: Bilgisayara güven](https://support.apple.com/en-us/109054)
- [Sideloadly: Kurulum ve yenileme](https://sideloadly.io/faq)
- [Apple: Foundation Models kullanılabilirliği](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models)
- [Apple: Model dilleri](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)
- [Apple: iOS 26.1 Türkçe desteği](https://support.apple.com/en-asia/121115)
- [Apple: Özel adapter izinleri (bu projede kullanılmıyor)](https://developer.apple.com/apple-intelligence/foundation-models-adapter)
