# Doğrulama kaydı

Tarih: 18 Ekim 2026

## Gerçekten çalıştırılan kontroller

- Swift 6.0.3, x86_64 Linux: çekirdek kaynaklar derlendi; **30 XCTest, 0 başarısızlık**.
- `swiftc -frontend -parse`: Core, Jarvis ve test dosyaları sözdizimi kontrolünden geçti.
- `project.yml` ve GitHub Actions YAML dosyaları ayrıştırıldı.
- Nihai arşivde derleme klasörü, derleyici, sertifika veya anahtar bulunmadığı kontrol edildi.

Bu ortamda Swift'in yeni sürücüsü süreç yönetiminde çöktüğü için son başarılı test komutu eski Swift sürücüsünü seçti:

```sh
swift test -j 1 -Xswiftc -disallow-use-new-driver
```

Bu bayrak bu test ortamına özgüdür. macOS GitHub akışında standart `swift test` kullanılır. Testler yalnızca kaynakların kopyası üzerinde çalışan taklit kontroller değildir; uygulamanın kullandığı `Sources/Core` modülünü derleyip yürütür.

## Testlerin kapsadığı riskler

İstanbul gün sınırı, tüm planların süre toplamı, bilinmeyen puanlar, günlük arşivleme, atlanan günler, çift tamamlama, boş sonuç notu, geçmiş güne tamamlama, geri alma, taslak koruma, sayaç duraklatma/sınırları, gece yarısı, bildirim zamanı/sayısı/tekilliği, tamamlanan görev bildirimi, adaptif görevin gerçek içeriği, günlük seri, kart tekrarları, eski veri geçişi, geçersiz JSON ve sürüm, kayıt ve geri okuma, bozuk dosya kurtarma, iki bozuk dosyada yazmama, gelecekteki sürümü eski yedeğe düşürmeme, prompt bütçesi, 12 alanın egzersizleri, bozuk adım ve tekrar seviyeleri, gece yarısı taslak notu.

## Bu kontrollerin kanıtlamadığı konular

- SwiftUI, Foundation Models, Speech ve UserNotifications API'lerinin iOS SDK ile tip kontrolü ve bağlanması.
- XcodeGen projesinin Xcode'da derlenmesi; GitHub Actions akışının başarıyla tamamlanması.
- Gerçek iPhone'da mikrofon/konuşma izinleri, ses tanıma kalitesi, model davranışı, bildirim teslimi, arayüz yerleşimi ve erişilebilirlik.
- iOS imzalama, IPA kurulumu veya TestFlight dağıtımı.

Bunlar için `CIHAZ-TESTI.md` ve macOS derleme akışı pakete eklendi. **Test geçti ifadesi bu bekleyen aşamaları kapsamıyor.**


## GitHub simülatör doğrulaması — 18 Ekim 2026

[Çalışma 39155744110](https://github.com/srqsrtc9kc-lgtm/jarvis-ios/actions/runs/39155744110),
`1e9446ddbccd6119a901022c5facc2b055e4e97d` commit'i: başarılı.
Xcode 26.6 (17F113), Swift 6.3.3. Çekirdek 30 test, iOS simülatör derlemesi
ve iOS birim testi adımları geçti. Önceki bölümde bekleyen olarak belirtilen
Xcode/SDK tip kontrolü ve simülatör derlemesi böylece doğrulandı.
Bu çalışmanın tek artifact'ı test sonuçlarıydı; iPhoneOS IPA üretmedi.

Yeni akış ayrıca `iphoneos`, `generic/platform=iOS`, `ARCHS=arm64`,
`CODE_SIGNING_ALLOWED=NO` ile Release derler. IPA artifact'ı yalnızca test,
derleme ve paket doğrulama adımları başarılıysa yüklenir. Her yeni çalışmanın
kesin sonucu Actions sayfası ve artifact içindeki `build-info.txt` ile izlenir.
Bu akışa sahip olmak tek başına başarılı derleme kanıtı değildir.
Gerçek cihaz kurulumu, kişisel yeniden imzalama, ses ve model testi beklemektedir.
