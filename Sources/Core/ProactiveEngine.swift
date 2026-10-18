import Foundation

/// Deterministic scheduling and greetings: reminders work even when no AI model is running.
enum ProactiveEngine {
    enum Period: String { case morning, afternoon, evening }

    static func period(at date: Date = Date(), settings: ProgramSettings = .init()) -> Period {
        let h = settings.calendar.component(.hour, from: date)
        if h < 12 { return .morning }
        if h < 18 { return .afternoon }
        return .evening
    }

    static func greetingKey(at date: Date = Date(), settings: ProgramSettings = .init()) -> String {
        "\(StudyCurriculum.dayKey(date, settings: settings))-\(period(at: date, settings: settings).rawValue)"
    }

    static func greeting(at date: Date = Date(), tasks: [StudyTask], settings: ProgramSettings = .init()) -> String {
        let incomplete = tasks.filter { !$0.done && $0.id != "review" }
        let next = incomplete.first
        switch period(at: date, settings: settings) {
        case .morning:
            let subject = next?.title ?? "kişisel gelişim tekrarın"
            return "Günaydın. Bugünkü gelişim programını düzenledim. İlk önceliğimiz: \(subject). " +
                "Çalışmayı birlikte yapacağız. Başlamak için hazır olduğunda cevap ver."
        case .afternoon:
            if let next {
                return "Günün ortasındayız. Hâlâ tamamlanmamış \(incomplete.count) çalışma var. " +
                    "Şimdi \(next.title) çalışmasına odaklanalım. Bugüne kadar ne yaptığını bana anlat."
            }
            return "Güzel. Bugünkü eğitim bloklarını tamamladın. En zorlandığın alanda kısa bir tekrar yapalım mı?"
        case .evening:
            let finished = tasks.filter(\.done).count
            return "Akşam değerlendirmesi zamanı. Bugün \(finished) görevi tamamladın. " +
                "Zorlandığın bir davranışı ve yarın geliştirmek istediğin bir noktayı anlat."
        }
    }
}
