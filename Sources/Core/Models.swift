import Foundation

enum StudyArea: String, Codable, CaseIterable, Identifiable {
    case diksiyon = "Diksiyon", konusma = "Konuşma & Karizma", satis = "Satış & İkna"
    case analiz = "Analitik Düşünme", hafiza = "Hafıza", kultur = "Genel Kültür"
    case sosyal = "Sosyal Beceri", disiplin = "Disiplin", sakinlik = "Soğukkanlılık"
    case bedenDili = "Beden Dili", ticariZeka = "Ticari Zekâ", liderlik = "Liderlik"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .diksiyon: "waveform"
        case .konusma: "person.crop.rectangle.stack"
        case .satis: "person.2.fill"
        case .analiz: "brain.head.profile"
        case .hafiza: "square.stack.3d.up"
        case .kultur: "globe.europe.africa"
        case .sosyal: "bubble.left.and.bubble.right"
        case .disiplin: "checkmark.seal"
        case .sakinlik: "wind"
        case .bedenDili: "figure.stand"
        case .ticariZeka: "chart.bar.xaxis"
        case .liderlik: "person.3.sequence.fill"
        }
    }
}

struct StudyTask: Identifiable, Codable, Equatable {
    var id: String
    var area: StudyArea
    var time: String
    var title: String
    var minutes: Int
    var instructions: String
    var done = false
}

struct CoachMessage: Identifiable, Codable {
    var id = UUID()
    var fromUser: Bool
    var text: String
    var date = Date()
    // Missing in v3: nil means an old, unlabelled message.
    var source: String? = nil
}

enum CoachMode: String, CaseIterable, Identifiable {
    case coach = "Koçluk", roleplay = "Satış simülasyonu"
    case exercise = "Egzersiz", analysis = "Eleştirel analiz"
    var id: String { rawValue }
}

struct ProgramSettings: Codable, Equatable {
    var dailyMinutes = 180
    var startHour = 9
    var timeZoneID = "Europe/Istanbul"
    var silenceSeconds = 3.0
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(identifier: "Europe/Istanbul")!
        return value
    }
    mutating func normalize() {
        if ![30, 60, 180].contains(dailyMinutes) { dailyMinutes = 60 }
        startHour = min(12, max(8, startHour))
        if TimeZone(identifier: timeZoneID) == nil { timeZoneID = "Europe/Istanbul" }
        if !silenceSeconds.isFinite { silenceSeconds = 3 }
        silenceSeconds = min(6, max(2, silenceSeconds))
    }
}

struct DayRecord: Codable, Identifiable {
    var day: String
    var tasks: [StudyTask]
    var id: String { day }
    var completed: Int { tasks.filter(\.done).count }
}

struct WorkLog: Codable, Identifiable {
    var id = UUID()
    var day: String
    var taskID: String
    var title: String
    var area: StudyArea
    var timerSeconds: Double
    var evidence: String
    var date: Date
}

struct PracticeSession: Codable, Identifiable {
    var id = UUID()
    var day: String
    var taskID: String
    var title: String
    var area: StudyArea
    var targetMinutes: Int
    var elapsedSeconds = 0.0
    var runningSince: Date? = nil
    var stepIndex = 0
    var answers: [String] = []
    func elapsed(at now: Date) -> Double {
        let running = runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return min(Double(targetMinutes * 60), max(0, elapsedSeconds) + running)
    }
    mutating func pause(at now: Date) { elapsedSeconds = elapsed(at: now); runningSince = nil }
}

struct RecallCard: Codable, Identifiable {
    var id = UUID()
    var question: String
    var answer: String
    var dueDay: String
    var level = 0
    mutating func review(recalled: Bool, at date: Date, settings: ProgramSettings) {
        level = recalled ? min(level + 1, 5) : 0
        let days = [1, 2, 4, 7, 14, 30][level]
        let next = settings.calendar.date(byAdding: .day, value: days, to: date) ?? date
        dueDay = StudyCurriculum.dayKey(next, settings: settings)
    }
}

struct JarvisMemory: Codable {
    var schemaVersion = 4
    var dateKey = ""
    var tasks: [StudyTask] = []
    var ratings: [String: Int] = [:]
    var messages: [CoachMessage] = []
    var notes = ""
    var completedTotal = 0
    var activeDays: [String] = []
    var review: [String] = []
    var settings = ProgramSettings()
    var history: [DayRecord] = []
    var logs: [WorkLog] = []
    var session: PracticeSession? = nil
    var recallCards: [RecallCard] = []
    init() {}
    enum CodingKeys: String, CodingKey {
        case schemaVersion, dateKey, tasks, ratings, messages, notes, completedTotal, activeDays, review
        case settings, history, logs, session, recallCards
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guard version <= 4 else { throw MemoryError.newerVersion }
        // A malformed or unrelated JSON object must never silently become a new profile.
        dateKey = try c.decode(String.self, forKey: .dateKey)
        tasks = try c.decode([StudyTask].self, forKey: .tasks)
        ratings = try c.decodeIfPresent([String: Int].self, forKey: .ratings) ?? [:]
        messages = try c.decodeIfPresent([CoachMessage].self, forKey: .messages) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        completedTotal = try c.decodeIfPresent(Int.self, forKey: .completedTotal) ?? 0
        activeDays = try c.decodeIfPresent([String].self, forKey: .activeDays) ?? []
        review = try c.decodeIfPresent([String].self, forKey: .review) ?? []
        settings = try c.decodeIfPresent(ProgramSettings.self, forKey: .settings) ?? ProgramSettings()
        history = try c.decodeIfPresent([DayRecord].self, forKey: .history) ?? []
        logs = try c.decodeIfPresent([WorkLog].self, forKey: .logs) ?? []
        session = try c.decodeIfPresent(PracticeSession.self, forKey: .session)
        recallCards = try c.decodeIfPresent([RecallCard].self, forKey: .recallCards) ?? []
        schemaVersion = 4
        settings.normalize()
        guard Set(tasks.map(\.id)).count == tasks.count,
              Set(history.map(\.day)).count == history.count,
              tasks.allSatisfy({ (1...240).contains($0.minutes) }) else { throw MemoryError.invalidData }
        if let session {
            guard session.day == dateKey, tasks.contains(where: { $0.id == session.taskID && !$0.done }),
                  (1...240).contains(session.targetMinutes), (0...3).contains(session.stepIndex),
                  session.answers.count <= 3, session.stepIndex <= session.answers.count,
                  session.elapsedSeconds.isFinite, session.elapsedSeconds >= 0 else { throw MemoryError.invalidData }
        }
        guard recallCards.allSatisfy({ (0...5).contains($0.level) }),
              logs.allSatisfy({ $0.timerSeconds.isFinite && $0.timerSeconds >= 0 }),
              Set(recallCards.map(\.id)).count == recallCards.count,
              Set(messages.map(\.id)).count == messages.count,
              Set(logs.map(\.id)).count == logs.count else { throw MemoryError.invalidData }
        ratings = ratings.mapValues { min(10, max(1, $0)) }
        completedTotal = max(0, completedTotal)
        activeDays = Array(Set(activeDays)).sorted()
    }
}

enum MemoryError: LocalizedError {
    case newerVersion, invalidData, noTask, evidenceRequired
    var errorDescription: String? {
        switch self {
        case .newerVersion: "Bu yedek daha yeni bir JARVIS sürümüne ait. Uygulamayı güncelle."
        case .invalidData: "Kayıt biçimi geçersiz. Mevcut verilerin değiştirilmedi."
        case .noTask: "Bu görev bugün açık değil. Güncel plandan bir görev seç."
        case .evidenceRequired: "Ne yaptığını en az 12 karakterle yaz. Bu kayıt kendi beyanındır; beceri ölçümü değildir."
        }
    }
}
