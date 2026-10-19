# JARVIS 4 · Yerel iPhone kişisel gelişim koçu

Güncelleme: 18 Ekim 2026 · Uygulama sürümü: 0.4.0

Bu paket, önceki JARVIS 3 iOS kaynaklarının geliştirilmiş sürümüdür. **SwiftUI kaynak kodu, 30 çekirdek davranış testi ve GitHub Actions kontrol akışı içerir. İmzalı IPA veya telefonuna kurulmuş uygulama değildir.** 18 Ekim 2026 tarihli GitHub çalışmasında iOS simülatör derlemesi ve testleri geçti. Gerçek iPhone testi yapılmadı. Windows kişisel kurulum yolu için [güncel rehberi](docs/WINDOWS-KURULUM.md) izle.

## Neler değişti?

- **Adım adım çalışma:** 12 gelişim alanında üçer somut egzersiz adımı; cevap kaydı, duraklatılabilen sayaç ve ayrı sonuç notu. “Tamamla” düğmesi en az 12 karakterlik sonuç notu ister. Bu, kullanıcı beyanıdır; çalışmanın yapıldığını bağımsız olarak doğrulamaz.
- **Gerçekçi günlük tempo:** 30, 60 veya 180 dakikalık plan; 08:00–12:00 arasında başlangıç saati. Saat dilimi İstanbul'dur. Değişiklikler sonraki plana uygulanır; henüz başlanmamış gün ayrıca yenilenebilir.
- **Daha sağlam hafıza:** UserDefaults içindeki v3 profilini okuyan geçiş, atomik JSON kaydı, son sağlam kopya, dışa/içe aktarma. Bozuk veya daha yeni sürümlü bir dosyanın üzerine sessizce boş profil yazılmaz.
- **Gelişimin görünmesi:** Gün arşivi, son yedi gün grafiği, çalışma sonuçları, sayaç süresi, aktif gün serisi. Hiç puan verilmemiş beceriler artık 5/10 gösterilmez.
- **Tekrar kartları:** Soru/cevap kaydı, önce hatırlama ve sonra cevabı gösterme; beyanına göre 1/2/4/7/14/30 günlük tekrar aralıkları. Bu basit bir tekrar düzenidir, kişiye göre doğrulanmış öğrenme algoritması iddiası yoktur.
- **AI yokken de çalışma:** Yerel model veya Türkçe desteği kullanılamıyorsa açıkça etiketli sabit rehberli egzersizler. Bunlar serbest konuşma veya mesajına özel AI değerlendirmesi değildir.
- **Kontrollü yerel AI:** Sınırlı bağlam, mesajın iki kere eklenmemesi, bağlam taşmasında bir kısa yeniden deneme, 35 saniye zaman aşımı ve iptal. AI, görevleri kendiliğinden tamamlayamaz.
- **Ses yönetimi:** Kullanıcı tarafından başlatılan eller serbest mod, ayarlanabilir konuşma sonu beklemesi, eski konuşma turlarının iptali, son kelimeyi bekleme, hata/arama/arka plan durumunda mikrofonu kapatma.
- **Bildirimler:** Yedi günlük plan, en fazla 35 bekleyen istek; bugünkü tamamlanan görevi çıkarma, doğru göreve yönlendirme, eski bildirimi güncel plandan ayırma. Yenilemeler sıraya alınır; kapatma sırasında eski isteklerin geri gelmesi engellenir.
- **Korunan taslak:** Gece yarısında yarım kalan adımlar, tamamlanmış sayılmadan günlük notuna taşınır.

## İlk kullanım

1. **Bugün** ekranında bir çalışma seç. İstersen süreyi Ayarlar'dan değiştir.
2. Sayaç başlatmak istersen oynat simgesine dokun. Her adımı uygula, kendi cevabını yaz ve kaydet.
3. Sonuç ekranına ne öğrendiğini yazıp tamamlamayı onayla.
4. **JARVIS** ekranında alan ve modu seçerek yazabilir veya mikrofona dokunabilirsin. İlk kullanımda iOS izinlerini tamamla; gerekiyorsa yeniden mikrofona dokun.
5. **Gelişim** ekranında öz değerlendirme, çalışma geçmişi ve tekrar kartlarını kullan.
6. **Ayarlar** ekranından bildirimleri aç ve arada yedeği dışa aktar.

Eller serbest varsayılan olarak kapalıdır. Açılış konuşması mikrofonu kendiliğinden açmaz. Uygulama etkinliğini kaybedince odak sayacı duraklar; başka uygulamada yaptığın çalışmanın süresini otomatik ölçmez.

## Windows ile derleme yolu

1. [Windows kurulum rehberini](docs/WINDOWS-KURULUM.md) izle. GitHub Actions akışı çekirdek ve simülatör testlerinden sonra gerçek iPhoneOS arm64 Release derlemesini imzasız üretir ve IPA yapısını doğrular.
2. Başarılı çalışmadaki **JARVIS-iPhoneOS-arm64-unsigned** artifact ZIP'ini indir; içindeki **JARVIS-unsigned.ipa** dosyasını çıkar.
3. Windows'ta Sideloadly ile kendi ücretsiz Apple hesabına yeniden imzalayıp yükle. Şifre ve 2FA yalnızca yerel Sideloadly/Apple ekranlarına girilir. TestFlight kullanılmaz.
4. Ücretsiz kişisel imza 7 gün geçerlidir; aynı hesap/uygulama kimliğiyle uygulamayı silmeden yenile. Kayıtlarını Ayarlar'dan dışa aktar.
5. Yeşil derleme sonucu, gerçek cihazdaki Türkçe model/ses kalitesini veya kurulum başarısını doğrulamaz. Cihaz kontrol listesi `docs/CIHAZ-TESTI.md` içindedir.

Mac üzerinde doğrudan:

```sh
brew install xcodegen
swift test
xcodegen generate
open JarvisKoc.xcodeproj
```

Xcode 26 veya üzeri ve iOS 26 veya üzeri hedeflenir. Yerel model ve Türkçe ses desteği çalışma anında denetlenir; iPhone 17 adı tek başına bütün koşulların sağlandığını garanti etmez.

## Veri ve gizlilik

- Uygulama kodunda bulut AI, API anahtarı, analitik SDK veya canlı internet araştırması yoktur. Ses tanıma yalnızca cihaz içi destek varsa başlatılır. Apple'ın model/ses indirmelerini iOS yönetir.
- Yeni profil `Application Support/JARVIS` altında, iOS dosya korumasıyla ve atomik yazımla tutulur. Bir önceki sağlam kayıt yedeklenir; bu ayrı bir parola ile şifrelenmiş yedek hizmeti değildir.
- iOS cihaz yedeklemesi ayarlarına göre bu dosyalar cihaz yedeğine dahil olabilir. Bir başka telefona uygulama içi otomatik eşitleme yapılmaz.
- Eski UserDefaults verisi, geçiş için korunur. Sohbet temizleme yeni profili temizler; eski v3 kopyası ve önceki dosya yedeği adli/güvenli silme anlamında yok edilmez.
- Sohbet görünümünde son 200 mesaj tutulur. Günlük notları, tamamlanan çalışmalar ve gün arşivi bu sınıra dahil değildir. İçe aktarma ve kayıt dosyası üst sınırı 10 MB'dır.
- JSON dışa aktarımı özel konuşma ve çalışma notlarını içerir. Geri yükleme açık onaydan sonra mevcut profilin yerini alır; önce dışa aktar.

## Doğrulanan ve bekleyenler

| Kontrol | Sonuç |
| --- | --- |
| Çekirdek Swift kodunun derlenmesi ve 30 XCTest | Geçti, 0 hata; Linux/Swift 6.0.3 |
| Tüm Swift kaynaklarının sözdizimi kontrolü | Geçti |
| Proje ve GitHub Actions YAML kontrolü | Geçti |
| Eski v3 profil biçimiyle geçiş testi | Geçti |
| iOS SDK ile tip kontrolü / Xcode simülatör derlemesi | [GitHub çalışması 39155744110](https://github.com/srqsrtc9kc-lgtm/jarvis-ios/actions/runs/39155744110) geçti |
| Gerçek iPhone: ses, model, bildirim, arayüz | Yapılmadı |
| IPA imzalama / TestFlight / App Store | Yapılmadı |

Ayrıntılı kayıt: `docs/DOGRULAMA.md`. Kaynak düzeyindeki kontrol, iPhone'da çalıştığının kanıtı değildir.

## Bilinçli sınırlar

Telefon kilitliyken sürekli “Jarvis” dinleme veya kendiliğinden canlı diyalog yoktur. Bildirim bir alarm değildir; AlarmKit eklenmedi. Yerel model kendi ağırlıklarını yeniden eğitmez. Öz değerlendirme ve sayaç süresi zekâ, karizma veya satış becerisi için objektif ölçüm değildir. Bildirimler uygulama açıldıkça yedi günlük pencereyi yeniler; yedi günden uzun süre açmazsan planlı bildirimler tükenir.

## Teknik kaynaklar

18 Ekim 2026 tarihinde kontrol edilen birincil belgeler:

- [Apple: Foundation Models kullanılabilirliği ve içerik üretimi](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models)
- [Apple: Dil ve bölge desteği](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)
- [Apple: Bağlam penceresini yönetme](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)
- [Apple: GenerationOptions](https://developer.apple.com/documentation/FoundationModels/GenerationOptions)
- [Apple: Ses tanıma görevini bitirme](https://developer.apple.com/documentation/speech/sfspeechrecognitiontask/finish())
- [GitHub: macOS runner görüntüleri](https://github.com/actions/runner-images)
