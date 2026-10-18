import Foundation

enum StudyCurriculum {
    static func dayKey(_ date: Date = Date(), settings: ProgramSettings = .init()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = settings.calendar
        f.timeZone = settings.calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    static func generalCultureTopic(_ date: Date = Date(), settings: ProgramSettings = .init()) -> String {
        let topics = ["Haftalık tekrar", "Ekonomi", "Tarih", "Bilim ve teknoloji", "Psikoloji", "İş dünyası", "Türkiye ve dünya"]
        return topics[settings.calendar.component(.weekday, from: date) - 1]
    }
    static func plan(for date: Date, ratings: [String: Int], settings: ProgramSettings = .init()) -> [StudyTask] {
        var safe = settings; safe.normalize()
        let day = safe.calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let unknown = StudyArea.allCases.filter { ratings[$0.rawValue] == nil }
        let minimum = ratings.values.min()
        let weak = StudyArea.allCases.filter { ratings[$0.rawValue] == minimum && minimum != nil }
        let pool = day % 3 == 0 && !unknown.isEmpty ? unknown : (!weak.isEmpty ? weak : StudyArea.allCases)
        let focus = pool[day % pool.count]
        let lengths = safe.dailyMinutes == 30 ? [8, 7, 7, 5, 3] : safe.dailyMinutes == 60 ? [15, 15, 15, 10, 5] : [50, 45, 45, 25, 15]
        let times = [safe.startHour * 60, safe.startHour * 60 + 70, safe.startHour * 60 + 135,
                     min(18 * 60, safe.startHour * 60 + 360), 21 * 60]
        func time(_ i: Int) -> String { String(format: "%02d:%02d", times[i] / 60, times[i] % 60) }
        return [
            .init(id: "voice", area: .diksiyon, time: time(0), title: "Diksiyon ve anlatım", minutes: lengths[0],
                  instructions: "Net okuma, 60 saniyelik anlatım ve ikinci deneme. Sesini kendin dinle; JARVIS metinden ses puanı vermez."),
            .init(id: "mind", area: .analiz, time: time(1), title: "Düşünme ve kültür · \(generalCultureTopic(date, settings: safe))", minutes: lengths[1],
                  instructions: "Önce kendi açıklamanı üret. Gözlemi yorumdan ayır, karşı kanıt yaz ve öğrendiğini üç cümleyle anlat."),
            .init(id: "sales", area: .satis, time: time(2), title: "İhtiyaç keşfi ve satış", minutes: lengths[2],
                  instructions: "Ürün anlatmadan önce müşterinin sorunu, etkisi ve karar sürecini sor. Gerçekçi bir sonraki adım iste."),
            .init(id: "adaptive", area: focus, time: time(3), title: "Özel çalışma · \(focus.rawValue)", minutes: lengths[3],
                  instructions: "Bu alan için rehberli egzersizi uygula. Bir örnek çıktı ve geliştireceğin bir davranış kaydet."),
            .init(id: "review", area: .disiplin, time: time(4), title: "Günlük değerlendirme", minutes: lengths[4],
                  instructions: "Yaptığını, zorlandığını ve yarınki en küçük adımı yaz. Bilgi kartlarını hatırlamayı dene.")
        ]
    }
}

struct LessonStep {
    var title: String
    var instruction: String
    var prompt: String
}

enum LessonLibrary {
    static func steps(for area: StudyArea) -> [LessonStep] {
        let rows: [(String, String, String)]
        switch area {
        case .diksiyon:
            rows = [("Netlik", "Rahat bir sesle kısa bir paragraf oku. Cümle sonlarında dur; kelime sonlarını tamamla. Zorlayarak yüksek ses çıkarma.", "Takıldığın üç kelimeyi yaz."),
                    ("Anlatım", "Bir fikri 60 saniyede fikir → gerekçe → örnek → sonuç sırasıyla anlat. Telefonunun kamerasıyla kayıt alıp kendin dinleyebilirsin.", "Ana fikrini ve verdiğin örneği yaz."),
                    ("İkinci deneme", "Aynı anlatımı tekrar et. İlk denemede fark ettiğin tek hatayı düzelt.", "İlk ve ikinci deneme arasında neyi değiştirdin?")]
        case .konusma:
            rows = [("Kendi fikrin", "Konu: İyi bir karar için hız mı, bilgi mi daha önemli? Yardım almadan önce bir görüş seç.", "Görüşünü tek cümleyle yaz."),
                    ("Gerekçe ve örnek", "Görüşünü bir gerekçe ve yaşadığın somut bir olayla anlat.", "Gerekçeni ve örneğini yaz."),
                    ("Karşı görüş", "Kendi fikrine en güçlü itirazı kur. Haklı olduğu koşulu belirt.", "Hangi koşulda fikrini değiştirirsin?")]
        case .satis:
            rows = [("İhtiyaç", "Sen işletmelere teslimat hizmeti sunuyorsun. Müşteri: Mevcut firmayla çalışıyoruz. Hemen teklif verme.", "Müşterinin yaşadığı sorunu açığa çıkaracak tek bir açık uçlu soru yaz."),
                    ("Etki", "Müşteri: Ayda birkaç teslimat gecikiyor ama idare ediyoruz. Bu bir eğitim senaryosudur.", "Gecikmenin işine etkisini anlamak için ne sorarsın?"),
                    ("Sonraki adım", "Müşteri: Daha pahalıysa değiştirmek istemem. Fiyat uydurma veya indirim vaat etme.", "Önce hangi bilgiyi netleştirir, ardından hangi küçük adımı önerirsin?")]
        case .analiz:
            rows = [("Gözlem", "Bir arkadaşın mesajına altı saattir cevap vermedi. Bu gözlemdir; seni önemsemediği ise bir yorumdur.", "Bu durumu açıklayan üç farklı ihtimal yaz."),
                    ("Karşı kanıt", "Bir ihtimali seç. Sadece onu doğrulayacak ayrıntıları aramak doğrulama yanlılığına yol açabilir.", "Seçtiğin açıklamayı zayıflatacak hangi gözlemi ararsın?"),
                    ("Kültür ve özet", "Bugünün kültür alanında güvenilir bir kaynaktan kısa bir bölüm oku. Güncel bilgi gerekiyorsa tarihi kontrol et; bu uygulama canlı araştırma yapmaz.", "Kaynak adıyla birlikte üç cümlelik özetini yaz.")]
        case .hafiza:
            rows = [("Kodlama", "30 saniye şu listeye bak: anahtar, limon, tren, kitap, mum. Nesneleri tek bir sıra dışı sahnede birleştir.", "Sahneni bir cümleyle yaz."),
                    ("Geri çağırma", "Önceki adıma bakmadan beş nesneyi sırasıyla hatırla.", "Hatırladığın nesneleri sırayla yaz."),
                    ("Kontrol", "Listenle ilk adımı karşılaştır. Kaçını hatırladığını kendin kaydet; sonuç bir IQ ölçümü değildir.", "Kaç doğru, hangi hata ve bir sonraki denemede hangi yöntem?")]
        case .kultur:
            rows = [("Ön bilgi", "Bugünün alanından bir kavram seç. Önce kaynağa bakmadan ne bildiğini yaz.", "Kavram nedir; şu an nasıl açıklarsın?"),
                    ("Kaynak kontrolü", "Güvenilir bir kaynakta açıklamasını oku. Olgu, görüş ve tahmini ayır.", "Kaynak adı/tarihi ve öğrendiğin iki bilgi nedir?"),
                    ("Öğret", "Kaynağı kapat. Kavramı konuya yabancı birine üç cümleyle anlat.", "Üç cümlelik açıklamanı yaz.")]
        case .sosyal:
            rows = [("Küçük adım", "Bugün uygun bir sosyal ortamda bir kişiye açık uçlu soru sor. Karşı tarafın istemediği sohbeti sürdürme.", "Kime, hangi bağlamda, ne soracaksın?"),
                    ("Dinleme", "Cevabı kesmeden dinle. Anladığını kendi sözlerinle kısa biçimde geri söyle.", "Ne söyledi; sen ne anladın?"),
                    ("Değerlendirme", "Tepkisini tahmin etmek yerine gözleyebildiğin davranışı kaydet.", "Gözlemin ne, yorumun ne; sonraki denemede neyi değiştireceksin?")]
        case .disiplin:
            rows = [("Gerçek durum", "Planladıklarınla yaptıklarını ayır. Yapılmayanı başarısız kişilik kanıtı sayma.", "Bugün gerçekten yaptığın tek somut iş ne?"),
                    ("Engel", "Ertelediğin işteki en küçük engeli seç: belirsizlik, ortam, süre veya başlangıç zorluğu.", "Asıl engel neydi; hangi gözlem bunu destekliyor?"),
                    ("Yarın", "Yeni bir büyük program yerine uygulanabilir bir başlangıç belirle.", "Hangi alışkanlıktan sonra, nerede, hangi iki dakikalık adımı yapacaksın?")]
        case .sakinlik:
            rows = [("Durumu ayır", "Hafif bir günlük gerilimi seç. Birkaç saniye dur, rahat nefes al ve cevap vermeyi ertele.", "Olay neydi; aklından geçen yorum neydi?"),
                    ("Seçenek", "Kontrol edebildiğin davranışları belirle. Karşı tarafın niyetini bildiğini varsayma.", "Verebileceğin üç farklı tepkiyi yaz."),
                    ("Sakin cevap", "İhtiyacını ve sınırını kısa, hakaretsiz bir cümleyle ifade et.", "Söyleyeceğin cümle ne?")]
        case .bedenDili:
            rows = [("Gözlem", "Kamerana 30 saniyelik bir tanışma konuşması kaydet. Kayıt bu uygulama tarafından alınmaz veya görülmez.", "Kendin izleyince duruşunda fark ettiğin iki davranış ne?"),
                    ("Tek değişiklik", "Omuzlarını rahat tut, yüzünü konuştuğun kişiye yönelt. Tek bir davranışı değiştir.", "Neyi değiştirmeyi seçtin?"),
                    ("Karşılaştır", "İkinci kaydı kendin izle. JARVIS görmediği görüntüye puan vermez.", "İki kayıttaki somut fark ne?")]
        case .ticariZeka:
            rows = [("Müşteri", "Bir iş fikri seç. Ürün özelliklerinden önce sorunu ve parayı kimin ödediğini tanımla.", "Kim, hangi sorun için, neden para öder?"),
                    ("Dağıtım", "Müşterinin kendiliğinden geleceğini varsayma. İlk beş aday müşteriye ulaşmanın somut yolunu seç.", "İlk müşteriye hangi kanaldan, hangi teklifle ulaşacaksın?"),
                    ("Çürütme", "Geliri kâr sayma. Zaman, edinme maliyeti ve değişken giderleri düşün; tahminleri açıkça işaretle.", "Fikri bırakmana neden olacak kanıt ve en ucuz doğrulama adımı nedir?")]
        case .liderlik:
            rows = [("Sonuç", "Hayali bir ekip arkadaşına görev vereceksin. Belirsiz bir emir yerine beklenen çıktıyı tanımla.", "İstenen çıktı, teslim zamanı ve başarı ölçütü nedir?"),
                    ("Anlaşma", "Görevi yapacak kişinin engellerini ve kaynak ihtiyacını sor.", "Anlaşılmayı kontrol etmek için ne sorarsın?"),
                    ("Geri bildirim", "Kişiliği yargılama; gözlenen davranış, etkisi ve sonraki adımı söyle.", "Kısa bir geri bildirim cümlesi yaz.")]
        }
        return rows.map { LessonStep(title: $0.0, instruction: $0.1, prompt: $0.2) }
    }
    static func fallback(focus: StudyArea, mode: CoachMode) -> String {
        let step = steps(for: focus)[0]
        if mode == .roleplay {
            return "Yerel AI kullanılamıyor; serbest müşteri diyaloğu yerine sabit satış çalışmasını açabilirsin. İlk soru: Mevcut tedarikçim varken neden seninle görüşeyim? Cevabını çalışma adımlarına kaydet."
        }
        return "Rehberli çalışma: \(step.instruction) \(step.prompt) Yanıtlarını Bugün ekranındaki çalışma adımlarına kaydedebilirsin. Bu sabit egzersiz, mesajına verilmiş bir AI değerlendirmesi değildir."
    }
}
