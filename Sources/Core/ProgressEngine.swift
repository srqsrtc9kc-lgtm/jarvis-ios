import Foundation

enum ProgressEngine {
    @discardableResult
    static func rollover(_ memory: inout JarvisMemory, at date: Date) -> Bool {
        let today = StudyCurriculum.dayKey(date, settings: memory.settings)
        guard memory.dateKey != today else { return false }
        let priorDay = memory.dateKey
        let missed = memory.tasks.filter { !$0.done && $0.id != "review" }
        if !priorDay.isEmpty {
            memory.history.removeAll { $0.day == priorDay }
            memory.history.append(.init(day: priorDay, tasks: memory.tasks))
        }
        if let draft = memory.session, !draft.answers.isEmpty {
            memory.review.append("\(priorDay): Tamamlanmamış çalışma taslağı — \(draft.title): " + draft.answers.joined(separator: " | "))
        }
        // Never count a suspended or previous day's timer as today's work.
        memory.session = nil
        memory.dateKey = today
        memory.tasks = StudyCurriculum.plan(for: date, ratings: memory.ratings, settings: memory.settings)
        if let priorDate = memory.settings.calendar.date(byAdding: .day, value: -1, to: date),
           StudyCurriculum.dayKey(priorDate, settings: memory.settings) == priorDay,
           !missed.isEmpty, let i = memory.tasks.firstIndex(where: { $0.id == "adaptive" }) {
            let day = memory.settings.calendar.ordinality(of: .day, in: .era, for: date) ?? 0
            let carry = missed[day % missed.count]
            memory.tasks[i].area = carry.area
            memory.tasks[i].title = "Dünkü eksik · \(carry.area.rawValue)"
            memory.tasks[i].instructions = "\(carry.title) alanını kısa çalışmayla tamamla. Ertelemenin nedenini sonuç notuna ekle."
        }
        return true
    }

    static func start(_ memory: inout JarvisMemory, taskID: String, at date: Date) throws {
        _ = rollover(&memory, at: date)
        guard let task = memory.tasks.first(where: { $0.id == taskID && !$0.done }) else { throw MemoryError.noTask }
        if memory.session?.taskID == taskID { return }
        // Switching is handled explicitly in the UI so draft answers cannot disappear silently.
        guard memory.session == nil else { throw MemoryError.invalidData }
        memory.session = .init(day: memory.dateKey, taskID: task.id, title: task.title, area: task.area, targetMinutes: task.minutes)
    }

    static func complete(_ memory: inout JarvisMemory, taskID: String, evidence: String, at date: Date) throws {
        let today = StudyCurriculum.dayKey(date, settings: memory.settings)
        guard memory.dateKey == today,
              let i = memory.tasks.firstIndex(where: { $0.id == taskID }) else { throw MemoryError.noTask }
        guard !memory.tasks[i].done else { return } // Idempotent on double taps.
        let note = evidence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard note.count >= 12 else { throw MemoryError.evidenceRequired }
        let task = memory.tasks[i]
        let seconds = memory.session?.taskID == taskID ? memory.session!.elapsed(at: date) : 0
        memory.tasks[i].done = true
        memory.completedTotal += 1
        if !memory.activeDays.contains(today) { memory.activeDays.append(today) }
        memory.logs.append(.init(day: today, taskID: taskID, title: task.title, area: task.area,
                                 timerSeconds: seconds, evidence: String(note.prefix(8000)), date: date))
        if memory.session?.taskID == taskID { memory.session = nil }
    }

    static func undo(_ memory: inout JarvisMemory, taskID: String) {
        guard let i = memory.tasks.firstIndex(where: { $0.id == taskID && $0.done }) else { return }
        memory.tasks[i].done = false
        memory.completedTotal = max(0, memory.completedTotal - 1)
        memory.logs.removeAll { $0.day == memory.dateKey && $0.taskID == taskID }
        if !memory.tasks.contains(where: \.done) { memory.activeDays.removeAll { $0 == memory.dateKey } }
    }

    static func streak(_ memory: JarvisMemory, at date: Date) -> Int {
        let cal = memory.settings.calendar
        let days = Set(memory.activeDays)
        var cursor = date
        if !days.contains(StudyCurriculum.dayKey(cursor, settings: memory.settings)) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var count = 0
        while days.contains(StudyCurriculum.dayKey(cursor, settings: memory.settings)) {
            count += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}

struct ReminderItem: Identifiable, Equatable {
    var id: String
    var day: String
    var taskID: String
    var title: String
    var body: String
    var fireDate: Date
}

enum ReminderPlanner {
    static func make(memory: JarvisMemory, now: Date) -> [ReminderItem] {
        let cal = memory.settings.calendar
        let todayKey = StudyCurriculum.dayKey(now, settings: memory.settings)
        var items: [ReminderItem] = []
        for offset in 0..<7 {
            guard let date = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let key = StudyCurriculum.dayKey(date, settings: memory.settings)
            let tasks = key == memory.dateKey ? memory.tasks : StudyCurriculum.plan(for: date, ratings: memory.ratings, settings: memory.settings)
            for task in tasks where !(key == todayKey && task.done) {
                let parts = task.time.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2, (8...21).contains(parts[0]), (0...59).contains(parts[1]),
                      let fire = cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date), fire > now else { continue }
                items.append(.init(id: "jarvis-\(key)-\(task.id)", day: key, taskID: task.id, title: task.title,
                                   body: "\(task.minutes) dakikalık çalışma hazır. Başlamak için dokun.", fireDate: fire))
            }
        }
        return items.sorted { $0.fireDate < $1.fireDate }
    }
}
