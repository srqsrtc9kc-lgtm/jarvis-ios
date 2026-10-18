# iPhone kabul kontrolü — henüz uygulanmadı

Bu liste Xcode derlemesi başarılı olduktan sonra gerçek cihazda uygulanmalıdır. Test sonucu doldurulmadan uygulama “cihazda doğrulandı” sayılmaz.

| Senaryo | Beklenen sonuç |
| --- | --- |
| İlk açılış; Apple Intelligence kapalı | Plan ve rehberli egzersizler açılır; AI durumu doğru açıklanır. |
| Türkçe model kullanılamıyor | Sabit egzersiz etiketi görünür; kişiselleştirilmiş AI değerlendirmesi iddia edilmez. |
| İlk mikrofon ve konuşma izni | Kullanıcı dokunmadan izin istenmez; reddedilince yazı girişi açık kalır. |
| İzin diyaloğu, uygulama arka plana geçişi | Eski izin dönüşü gizlice mikrofonu başlatmaz; yeniden başlatmak kullanıcıya aittir. |
| Uçak modu | Model paketi hazırsa yerel işlevler denenir; kayıt sunucuya yönlendirilmez. |
| Manuel konuşma bitirme | Son kelime korunur, tek mesaj gönderilir. |
| Eller serbest, 10 dakika konuşma | Yanıt mikrofon tarafından tekrar alınmaz; çift mesaj ve izinsiz yeniden başlatma olmaz. |
| “Durdur”, gelen arama, kulaklık çıkarma | Mikrofon ve ses durur; kesilen yanıt sonradan seslendirilmez. |
| Yavaş model veya iptal | 35 saniye sonra arayüz serbest kalır; geç gelen eski yanıt eklenmez. |
| Görev değiştirme | Mevcut taslak onaysız atılmaz. |
| Sonuç notu boşken tamamlama | Görev tamamlanmaz. |
| Tamamla düğmesine hızlı çift dokunma | Tek kayıt ve tek sayaç artışı. |
| Son tamamlamayı geri alma | Toplam/aktif gün tutarlı; diğer günler korunur. |
| Uygulamayı arka plana alıp 10 dakika bekleme | Bu süre sayaç süresine eklenmez. |
| İstanbul saatiyle gece yarısı | Önceki gün arşivlenir, taslak cevaplar notlara geçer, yeni plan oluşur. |
| Yeni / eski bildirimden soğuk açılış | Yeni bildirim doğru görevi açar; eski bildirim bugünkü planı gösterir. |
| Bildirimleri yenilerken kapatma | Kapatılmış istekler yeniden eklenmez. |
| 30/60/180 dakika değişimi | Başlanmış gün korunur; sonraki gün doğru süre toplamı oluşur. |
| Yedek dışa/içe aktarma | Konuşmalar, görevler, notlar ve kartlar korunur; uygulama önceden onay ister. |
| Bozuk/yeni sürümlü yedek | Mevcut profil değişmez; anlaşılır hata görünür. |
| Büyük metin ve VoiceOver | Düğmeler erişilebilir; sonuç notu/gönderme alanı klavyenin altında kalmaz. |
| Sessiz mod / Odak açıkken bildirim | iOS'un gerçek teslim davranışı not edilir; alarm garantisi verilmez. |

Ölçüm: cihaz modeli, iOS sürümü, model/dil durumu, 30 Türkçe giriş örneğinde yanlış sözcük sayısı, yanıt gecikmesi ve başarısız akışlar kaydedilsin. Bu sonuçlar şu an bilinmiyor.
