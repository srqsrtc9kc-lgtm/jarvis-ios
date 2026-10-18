import Foundation
import FoundationModels
import Combine

@MainActor
final class JarvisStore: ObservableObject {
    @Published private(set) var memory: JarvisMemory
    @Published private(set) var isThinking = false
    @Published var errorMessage: String?
    @Published var storageWarning: String?
    @Published var focus: StudyArea = .konusma
    @Published var coachMode: CoachMode = .coach
    @Published var selectedTab = 0
    @Published var showPractice = false
    @Published var reminderStatus = ""
    private let repository: MemoryRepository
    private var writable = true
    private var requestID: UUID?
    private var generationTask: Task<String, Error>?
    private var timeoutTask: Task<Void, Never>?

    init() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        repository = MemoryRepository(directory: root.appendingPathComponent("JARVIS", isDirectory: true))
        var recovered = JarvisMemory()
        do {
            let loaded = try repository.load()
            if let value = loaded.memory { recovered = value }
            else if let old = UserDefaults.standard.data(forKey: "jarvis-local-memory-v1") {
                recovered = try repository.decode(old)
            }
            if loaded.recovered { storageWarning = "Son kayıt okunamadı; son sağlam yedek açıldı. Son değişiklikler eksik olabilir." }
        } catch {
            writable = false
            storageWarning = "Kayıt açılamadı ve üzerine yazma durduruldu. Ayarlar'dan sağlam bir yedeği içe aktar. \(error.localizedDescription)"
        }
        // A killed process cannot prove how long the user continued working.
        recovered.session?.runningSince = nil
        memory = recovered
        updateForToday()
    }
    var tasks: [StudyTask] { memory.tasks }
    var recentMessages: [CoachMessage] { memory.messages }
    var completedToday: Int { tasks.filter(\.done).count }
    var totalToday: Int { tasks.count }
    var ratings: [String: Int] { memory.ratings }
    var notes: String { memory.notes }
    var modelReady: Bool {
        SystemLanguageModel.default.isAvailable && SystemLanguageModel.default.supportsLocale(Locale(identifier: "tr_TR"))
    }
    var modelStatus: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return SystemLanguageModel.default.supportsLocale(Locale(identifier: "tr_TR"))
                ? "Türkçe yerel AI hazır" : "Türkçe model desteği yok · Rehberli çalışma hazır"
        case .unavailable(.deviceNotEligible): return "Cihaz yerel AI için uygun değil · Rehberli çalışma hazır"
        case .unavailable(.appleIntelligenceNotEnabled): return "Apple Intelligence kapalı · Rehberli çalışma hazır"
        case .unavailable(.modelNotReady): return "Yerel model hazırlanıyor · Rehberli çalışma hazır"
        case .unavailable: return "Yerel AI kullanılamıyor · Rehberli çalışma hazır"
        @unknown default: return "Model durumu bilinmiyor · Rehberli çalışma hazır"
        }
    }
    func updateForToday() {
        if ProgressEngine.rollover(&memory, at: Date()) { persist(); refreshReminders() }
    }
    func refreshReminders() {
        let snapshot = memory
        Task { [weak self] in
            do { try await JarvisNotifications.shared.refresh(memory: snapshot) }
            catch { self?.reminderStatus = "Bildirimler yenilenemedi: \(error.localizedDescription)" }
        }
    }
    func openPractice(_ taskID: String) {
        do {
            try ProgressEngine.start(&memory, taskID: taskID, at: Date())
            focus = memory.session?.area ?? .konusma
            persist(); showPractice = true
        } catch { errorMessage = memory.session != nil ? "Önce devam eden çalışmayı bitir veya çalışma ekranından taslağı bırak." : error.localizedDescription }
    }
    func pausePractice() {
        memory.session?.pause(at: Date()); persist()
    }
    func toggleTimer() {
        guard memory.session != nil else { return }
        if memory.session?.runningSince == nil { memory.session?.runningSince = Date() }
        else { memory.session?.pause(at: Date()) }
        persist()
    }
    func saveStep(_ answer: String) {
        guard var session = memory.session else { return }
        let clean = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if session.stepIndex < session.answers.count { session.answers[session.stepIndex] = String(clean.prefix(1500)) }
        else { session.answers.append(String(clean.prefix(1500))) }
        session.stepIndex = min(LessonLibrary.steps(for: session.area).count, session.stepIndex + 1)
        memory.session = session; persist()
    }
    func previousStep() {
        guard memory.session != nil else { return }
        memory.session?.stepIndex = max(0, (memory.session?.stepIndex ?? 0) - 1); persist()
    }
    func abandonPractice() { memory.session = nil; persist(); showPractice = false }
    func finishPractice(_ note: String) {
        guard let session = memory.session else { return }
        do {
            // Require a separate explicit result note; copied lesson prompts do not count as completion.
            guard note.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12 else { throw MemoryError.evidenceRequired }
            let evidence = (session.answers + ["Sonuç: " + note]).joined(separator: "\n")
            try ProgressEngine.complete(&memory, taskID: session.taskID, evidence: evidence, at: Date())
            persist(); refreshReminders(); showPractice = false
        } catch { errorMessage = error.localizedDescription }
    }
    func undo(_ id: String) { ProgressEngine.undo(&memory, taskID: id); persist(); refreshReminders() }
    func rate(_ area: StudyArea, score: Int) { memory.ratings[area.rawValue] = min(10, max(1, score)); persist() }
    func addReview(_ note: String) {
        let clean = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        memory.review.append("\(memory.dateKey): \(String(clean.prefix(2000)))"); persist()
    }
    func saveNotes(_ text: String) { memory.notes = String(text.prefix(1300)); persist() }
    func updateSettings(_ settings: ProgramSettings) {
        memory.settings = settings; memory.settings.normalize(); persist(); refreshReminders()
    }
    func rebuildUnstartedPlan() {
        guard memory.session == nil && !memory.tasks.contains(where: \.done) else {
            errorMessage = "Başlanmış plan korunur. Yeni süre ve saatler yarın uygulanacak."; return
        }
        memory.tasks = StudyCurriculum.plan(for: Date(), ratings: ratings, settings: memory.settings)
        persist(); refreshReminders()
    }
    func addCard(question: String, answer: String) {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !a.isEmpty else { return }
        memory.recallCards.append(.init(question: String(q.prefix(500)), answer: String(a.prefix(1500)), dueDay: memory.dateKey))
        persist()
    }
    func reviewCard(_ id: UUID, recalled: Bool) {
        guard let i = memory.recallCards.firstIndex(where: { $0.id == id }) else { return }
        memory.recallCards[i].review(recalled: recalled, at: Date(), settings: memory.settings); persist()
    }
    func clearHistory() { cancelReply(); memory.messages.removeAll(); persist() }
    func exportData() throws -> Data { try repository.export(memory) }
    func validateImport(_ data: Data) throws -> JarvisMemory { try repository.decode(data) }
    func restore(_ imported: JarvisMemory) throws {
        var restored = imported; restored.session?.runningSince = nil
        _ = ProgressEngine.rollover(&restored, at: Date())
        // Save before swapping UI state; failed writes leave the current profile usable.
        try repository.save(restored)
        cancelReply(); memory = restored; writable = true; storageWarning = nil; refreshReminders()
    }
    func handleNotification() {
        guard let route = NotificationRoute.consume() else { return }
        updateForToday(); selectedTab = 0
        if route.day != memory.dateKey { errorMessage = "Bu eski bir bildirim. Bugünkü plan açıldı."; return }
        if tasks.first(where: { $0.id == route.taskID })?.done == true { return }
        openPractice(route.taskID)
    }
    func cancelReply() {
        requestID = nil; generationTask?.cancel(); timeoutTask?.cancel(); isThinking = false
    }
    func ask(_ text: String, focus: StudyArea, mode: CoachMode) async -> String? {
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        guard !clean.isEmpty, !isThinking else { return nil }
        updateForToday()
        let prompt = CoachPrompt.make(memory: memory, text: clean, focus: focus, mode: mode)
        let compact = CoachPrompt.make(memory: memory, text: clean, focus: focus, mode: mode, compact: true)
        memory.messages.append(.init(fromUser: true, text: clean)); persist()
        errorMessage = nil
        guard modelReady else { return appendAnswer(LessonLibrary.fallback(focus: focus, mode: mode), source: "Rehberli egzersiz") }
        let id = UUID(); requestID = id; isThinking = true
        let generation = Task<String, Error> {
            do {
                let session = LanguageModelSession(instructions: CoachPrompt.instructions)
                return try await session.respond(to: prompt, options: GenerationOptions(maximumResponseTokens: 420)).content
            } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
                try Task.checkCancellation()
                let session = LanguageModelSession(instructions: CoachPrompt.instructions)
                return try await session.respond(to: compact, options: GenerationOptions(maximumResponseTokens: 300)).content
            }
        }
        generationTask = generation
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 35_000_000_000) } catch { return }
            guard let self, self.requestID == id else { return }
            self.cancelReply(); self.errorMessage = "Yanıt zaman aşımına uğradı. Yeniden deneyebilir veya rehberli çalışmaya geçebilirsin."
        }
        do {
            let result = try await generation.value
            guard requestID == id, !Task.isCancelled else { return nil }
            timeoutTask?.cancel(); isThinking = false; requestID = nil
            let cleanResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanResult.isEmpty else { errorMessage = "Yerel model boş yanıt verdi. Tekrar dene."; return nil }
            return appendAnswer(cleanResult, source: "Yerel AI")
        } catch {
            guard requestID == id else { return nil }
            timeoutTask?.cancel(); isThinking = false; requestID = nil
            errorMessage = "Yerel AI yanıt veremedi. Rehberli çalışma kullanılabilir. \(error.localizedDescription)"
            return nil
        }
    }
    private func appendAnswer(_ text: String, source: String) -> String {
        memory.messages.append(.init(fromUser: false, text: text, source: source))
        memory.messages = Array(memory.messages.suffix(200)); persist(); return text
    }
    private func persist() {
        guard writable else { return }
        do { try repository.save(memory) }
        catch { storageWarning = "Son değişiklikler kaydedilemedi. Uygulamayı kapatmadan yedek dışa aktar. \(error.localizedDescription)" }
    }
}
