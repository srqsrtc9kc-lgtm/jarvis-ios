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
