import SwiftUI
import Charts

struct StatsScreen: View {
    @EnvironmentObject private var store: JarvisStore
    @State private var review = ""
    @State private var cardQuestion = ""
    @State private var cardAnswer = ""
    @State private var revealed: UUID?
    private var weekly: [DayRecord] {
        let memory = store.memory
        return (0..<7).reversed().compactMap { offset in
            guard let day = memory.settings.calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let key = StudyCurriculum.dayKey(day, settings: memory.settings)
            if key == memory.dateKey { return DayRecord(day: key, tasks: memory.tasks) }
            return memory.history.first(where: { $0.day == key }) ?? DayRecord(day: key, tasks: [])
        }
    }
    private var dueCards: [RecallCard] { store.memory.recallCards.filter { $0.dueDay <= store.memory.dateKey } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Panel {
                        HStack {
                            metric("TAMAMLANAN", value: "\(store.memory.completedTotal)")
                            Spacer()
                            metric("GÜNLÜK SERİ", value: "\(ProgressEngine.streak(store.memory, at: Date()))")
                            Spacer()
                            metric("SAYAÇ / DK", value: "\(Int(store.memory.logs.reduce(0) { $0 + $1.timerSeconds } / 60))")
                        }
                    }
                    Text("Tamamlanma kayıtları senin beyanın; sayaç süresi ve öz değerlendirme beceri ölçümü değildir.")
                        .font(.caption).foregroundStyle(.secondary)
                    Panel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Son 7 gün").font(.headline)
                            Chart(weekly) { day in
                                BarMark(x: .value("Gün", String(day.day.suffix(5))), y: .value("Görev", day.completed)).foregroundStyle(.cyan)
                            }.frame(height: 150).chartYScale(domain: 0...5)
                            Text("Boş günler 0 gösterilir. Arşivde bulunmayan günler için çalışma varsayılmaz.").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Text("ÖZ DEĞERLENDİRME").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(StudyArea.allCases) { area in
                        Panel {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack { Label(area.rawValue, systemImage: area.icon); Spacer() }
                                HStack {
                                    if let score = store.ratings[area.rawValue] { Text("\(score)/10 · kendi değerlendirmen").foregroundStyle(.cyan) }
                                    else { Text("Henüz değerlendirilmedi").foregroundStyle(.secondary) }
                                    Spacer()
                                    Stepper("Öz değerlendirme puanı", value: Binding(get: { store.ratings[area.rawValue] ?? 5 }, set: { store.rate(area, score: $0) }), in: 1...10).labelsHidden()
                                }.font(.caption)
                            }
                        }
                    }
                    Panel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hatırla · \(dueCards.count) kart").font(.headline)
                            if let card = dueCards.first {
                                Text(card.question)
                                if revealed == card.id {
                                    Text(card.answer).foregroundStyle(.cyan)
                                    HStack {
                                        Button("Hatırlamadım") { store.reviewCard(card.id, recalled: false); revealed = nil }
                                        Spacer()
                                        Button("Hatırladım") { store.reviewCard(card.id, recalled: true); revealed = nil }
                                    }.buttonStyle(.bordered)
                                } else { Button("Önce cevapla, sonra göster") { revealed = card.id }.buttonStyle(.bordered) }
                            } else { Text("Bugün tekrar zamanı gelen kart yok.").foregroundStyle(.secondary) }
                            DisclosureGroup("Yeni bilgi kartı") {
                                TextField("Soru", text: $cardQuestion, axis: .vertical).textFieldStyle(.roundedBorder)
                                TextField("Cevap", text: $cardAnswer, axis: .vertical).textFieldStyle(.roundedBorder)
                                Button("Kartı ekle") { store.addCard(question: cardQuestion, answer: cardAnswer); cardQuestion = ""; cardAnswer = "" }
                                    .disabled(cardQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cardAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Günlük notun").font(.headline)
                            TextField("Ne yaptın, ne öğrendin, yarın neyi değiştireceksin?", text: $review, axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder)
                            Button("Notu kaydet") { store.addReview(review); review = "" }.buttonStyle(.bordered)
                                .disabled(review.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            ForEach(Array(store.memory.review.suffix(5).reversed().enumerated()), id: \.offset) { _, note in
                                Text(note).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if !store.memory.logs.isEmpty {
                        Text("SON ÇALIŞMA KAYITLARI").font(.caption.bold()).foregroundStyle(.secondary)
                        ForEach(store.memory.logs.suffix(10).reversed()) { log in
                            Panel {
                                DisclosureGroup("\(log.day) · \(log.title)") {
                                    Text(log.evidence).font(.footnote).textSelection(.enabled)
                                    Text("Sayaç: \(Int(log.timerSeconds / 60)) dk · Kullanıcı beyanı").font(.caption).foregroundStyle(.secondary)
                                }.font(.subheadline)
                            }
                        }
                    }
                }.padding(20)
            }.navigationTitle("Gelişim")
        }
    }
    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary); Text(value).font(.title.bold().monospacedDigit()) }
    }
}
