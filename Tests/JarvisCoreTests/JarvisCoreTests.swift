import XCTest
#if canImport(JarvisCore)
@testable import JarvisCore
#else
@testable import JarvisKoc
#endif

final class JarvisCoreTests: XCTestCase {
    func date(_ value: String = "2026-10-18T06:00:00Z") -> Date { ISO8601DateFormatter().date(from: value)! }
    func fresh(at now: Date? = nil) -> JarvisMemory {
        var m = JarvisMemory(); ProgressEngine.rollover(&m, at: now ?? date()); return m
    }
    func testIstanbulDayBoundaryIndependentOfMachineZone() {
        XCTAssertEqual(StudyCurriculum.dayKey(date("2026-10-18T20:59:59Z")), "2026-10-18")
        XCTAssertEqual(StudyCurriculum.dayKey(date("2026-10-18T21:00:00Z")), "2026-10-19")
    }
    func testPlansRespectAllBudgetsAndNeverLoseAreas() {
        for budget in [30, 60, 180] {
            var s = ProgramSettings(); s.dailyMinutes = budget
            let plan = StudyCurriculum.plan(for: date(), ratings: [:], settings: s)
            XCTAssertEqual(plan.reduce(0) { $0 + $1.minutes }, budget)
            XCTAssertEqual(Set(plan.map(\.id)).count, 5)
            XCTAssertTrue(plan.allSatisfy { $0.minutes > 0 && !$0.done })
        }
        XCTAssertEqual(StudyArea.allCases.count, 12)
    }
    func testUnknownRatingsStayUnknown() {
        let m = fresh()
        XCTAssertTrue(m.ratings.isEmpty)
        XCTAssertTrue(CoachPrompt.make(memory: m, text: "Başla", focus: .satis, mode: .coach).contains("ölçülmedi"))
    }
    func testRolloverArchivesDayOnceAndKeepsCompletion() throws {
        var m = fresh()
        try ProgressEngine.complete(&m, taskID: "voice", evidence: "İki kısa konuşma kaydı yaptım.", at: date())
        XCTAssertTrue(ProgressEngine.rollover(&m, at: date("2026-10-19T06:00:00Z")))
        XCTAssertFalse(ProgressEngine.rollover(&m, at: date("2026-10-19T07:00:00Z")))
        XCTAssertEqual(m.history.count, 1); XCTAssertEqual(m.history.first?.completed, 1)
        XCTAssertEqual(m.completedTotal, 1); XCTAssertFalse(m.tasks.contains(where: \.done))
    }
    func testSkippedDaysAreNotInventedOrCalledYesterday() {
        var m = fresh()
        ProgressEngine.rollover(&m, at: date("2026-10-25T06:00:00Z"))
        XCTAssertEqual(m.history.count, 1)
        XCTAssertFalse(m.tasks.contains { $0.title.contains("Dünkü") })
    }
    func testCompletionIsIdempotent() throws {
        var m = fresh()
        for _ in 0..<3 { try ProgressEngine.complete(&m, taskID: "voice", evidence: "Kelime sonlarını tamamlayarak tekrar okudum.", at: date()) }
        XCTAssertEqual(m.completedTotal, 1); XCTAssertEqual(m.logs.count, 1); XCTAssertEqual(m.activeDays.count, 1)
    }
    func testEmptyEvidenceCannotCompleteOrMutate() {
        var m = fresh()
        XCTAssertThrowsError(try ProgressEngine.complete(&m, taskID: "voice", evidence: " bitti ", at: date()))
        XCTAssertEqual(m.completedTotal, 0); XCTAssertTrue(m.logs.isEmpty); XCTAssertFalse(m.tasks[0].done)
    }
    func testStaleCompletionDoesNotCountForNewDay() {
        var m = fresh()
        XCTAssertThrowsError(try ProgressEngine.complete(&m, taskID: "voice", evidence: "Konuşma denemesini tamamladım.", at: date("2026-10-19T06:00:00Z")))
        XCTAssertEqual(m.completedTotal, 0)
    }
    func testUndoRemovesOnlyCurrentTaskAndIsIdempotent() throws {
        var m = fresh()
        try ProgressEngine.complete(&m, taskID: "voice", evidence: "İki deneme yaptım ve karşılaştırdım.", at: date())
        ProgressEngine.undo(&m, taskID: "voice"); ProgressEngine.undo(&m, taskID: "voice")
        XCTAssertEqual(m.completedTotal, 0); XCTAssertTrue(m.logs.isEmpty); XCTAssertTrue(m.activeDays.isEmpty)
    }
    func testSwitchingTaskDoesNotDiscardDraft() throws {
        var m = fresh(); try ProgressEngine.start(&m, taskID: "voice", at: date())
        m.session?.answers = ["Önceki cevabım"]
        XCTAssertThrowsError(try ProgressEngine.start(&m, taskID: "sales", at: date()))
        XCTAssertEqual(m.session?.answers, ["Önceki cevabım"])
    }
    func testPausedTimerNeverCountsTimeAway() throws {
        var m = fresh(); try ProgressEngine.start(&m, taskID: "voice", at: date())
        m.session?.runningSince = date(); m.session?.pause(at: date().addingTimeInterval(45))
        XCTAssertEqual(m.session?.elapsed(at: date().addingTimeInterval(600)), 45)
    }
    func testTimerCapsTargetAndRejectsBackwardClock() {
        var s = PracticeSession(day: "2026-10-18", taskID: "voice", title: "Test", area: .diksiyon, targetMinutes: 5)
        s.runningSince = date()
        XCTAssertEqual(s.elapsed(at: date().addingTimeInterval(-100)), 0)
        XCTAssertEqual(s.elapsed(at: date().addingTimeInterval(86_400)), 300)
    }
    func testRolloverClearsPreviousDaySession() throws {
        var m = fresh(); try ProgressEngine.start(&m, taskID: "voice", at: date())
        ProgressEngine.rollover(&m, at: date("2026-10-19T06:00:00Z"))
        XCTAssertNil(m.session)
    }
    func testNotificationsAreFutureUniqueAndWithinQuietHours() {
        let now = date("2026-10-18T17:00:00Z")
        let m = fresh(at: now); let requests = ReminderPlanner.make(memory: m, now: now)
        XCTAssertLessThanOrEqual(requests.count, 35)
        XCTAssertEqual(Set(requests.map(\.id)).count, requests.count)
        XCTAssertTrue(requests.allSatisfy { $0.fireDate > now })
        XCTAssertTrue(requests.allSatisfy { (8...21).contains(m.settings.calendar.component(.hour, from: $0.fireDate)) })
    }
    func testDoneTaskNotificationRemovedOnlyForToday() throws {
        let now = date("2026-10-18T04:00:00Z")
        var m = fresh(at: now)
        try ProgressEngine.complete(&m, taskID: "voice", evidence: "Sabah erken iki deneme yaptım.", at: now)
        let requests = ReminderPlanner.make(memory: m, now: now)
        XCTAssertFalse(requests.contains { $0.day == "2026-10-18" && $0.taskID == "voice" })
        XCTAssertTrue(requests.contains { $0.day == "2026-10-19" && $0.taskID == "voice" })
    }
    func testNotificationUsesActualAdaptiveTaskNotRegeneratedPlan() {
        let now = date("2026-10-18T04:00:00Z"); var m = fresh(at: now)
        m.tasks[3].title = "Özel hafıza çalışmam"
        XCTAssertEqual(ReminderPlanner.make(memory: m, now: now).first { $0.day == m.dateKey && $0.taskID == "adaptive" }?.title, "Özel hafıza çalışmam")
    }
    func testStreakSurvivesUnfinishedTodayAndBreaksOnGap() {
        var m = fresh(); m.activeDays = ["2026-10-16", "2026-10-17"]
        XCTAssertEqual(ProgressEngine.streak(m, at: date()), 2)
        m.activeDays = ["2026-10-15", "2026-10-17"]
        XCTAssertEqual(ProgressEngine.streak(m, at: date()), 1)
    }
    func testRecallFailureResetsScheduleAndSuccessExtendsIt() {
        var card = RecallCard(question: "Nedir?", answer: "Bir kavram.", dueDay: "2026-10-18")
        card.review(recalled: true, at: date(), settings: .init())
        XCTAssertEqual(card.dueDay, "2026-10-20")
        card.review(recalled: false, at: date(), settings: .init())
        XCTAssertEqual(card.dueDay, "2026-10-19"); XCTAssertEqual(card.level, 0)
    }
    func testLegacyV3DataMigratesWithoutLosingNotes() throws {
        let json = #"{"dateKey":"2026-10-18","tasks":[],"ratings":{"Satış & İkna":3},"messages":[],"notes":"Kendi fikrimi önce sor.","completedTotal":7,"activeDays":["2026-10-17"],"review":["İlk not"]}"#
        let m = try JSONDecoder().decode(JarvisMemory.self, from: Data(json.utf8))
        XCTAssertEqual(m.schemaVersion, 4); XCTAssertEqual(m.completedTotal, 7)
        XCTAssertEqual(m.notes, "Kendi fikrimi önce sor."); XCTAssertEqual(m.review.count, 1)
        XCTAssertEqual(m.settings.timeZoneID, "Europe/Istanbul")
    }
    func testUnknownJSONIsNotAcceptedAsEmptyProfile() {
        XCTAssertThrowsError(try JSONDecoder().decode(JarvisMemory.self, from: Data("{}".utf8)))
    }
    func testFutureSchemaRejected() {
        XCTAssertThrowsError(try JSONDecoder().decode(JarvisMemory.self, from: Data(#"{"schemaVersion":99,"dateKey":"","tasks":[]}"#.utf8)))
    }
    func repository() throws -> MemoryRepository {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return MemoryRepository(directory: directory)
    }
    func testAtomicSaveRoundTripPreservesEvidenceAndSession() throws {
        let repo = try repository(); var m = fresh()
        try ProgressEngine.complete(&m, taskID: "voice", evidence: "Diksiyon çalışmasında üç kelimeyi düzelttim.", at: date())
        try ProgressEngine.start(&m, taskID: "mind", at: date())
        try repo.save(m); let loaded = try XCTUnwrap(repo.load().memory)
        XCTAssertEqual(loaded.logs.first?.evidence, m.logs.first?.evidence)
        XCTAssertEqual(loaded.session?.taskID, "mind")
    }
    func testCorruptPrimaryRecoversBackupAndPreservesCorruptBytesUntilSave() throws {
        let repo = try repository(); var m = fresh(); m.notes = "Sağlam kayıt"
        try repo.save(m)
        let corrupt = Data("broken".utf8); try corrupt.write(to: repo.fileURL)
        let result = try repo.load()
        XCTAssertTrue(result.recovered); XCTAssertEqual(result.memory?.notes, "Sağlam kayıt")
        XCTAssertEqual(try Data(contentsOf: repo.fileURL), corrupt)
        try repo.save(try XCTUnwrap(result.memory))
        XCTAssertEqual(try repo.decode(Data(contentsOf: repo.backupURL)).notes, "Sağlam kayıt")
    }
    func testBothCorruptFilesFailWithoutWriting() throws {
        let repo = try repository(); try repo.save(fresh())
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: repo.fileURL); try corrupt.write(to: repo.backupURL)
        XCTAssertThrowsError(try repo.load())
        XCTAssertEqual(try Data(contentsOf: repo.fileURL), corrupt)
    }
    func testNewerPrimaryNeverRollsBackToOldBackup() throws {
        let repo = try repository(); try repo.save(fresh())
        try Data(#"{"schemaVersion":99,"dateKey":"","tasks":[]}"#.utf8).write(to: repo.fileURL)
        XCTAssertThrowsError(try repo.load())
    }
    func testPromptBudgetAndNoDuplicateCurrentInput() {
        var m = fresh(); m.notes = String(repeating: "çok uzun not ", count: 1000)
        m.messages = (0..<30).map { _ in CoachMessage(fromUser: true, text: String(repeating: "geçmiş ", count: 300)) }
        let text = "BENİM_SON_MESAJIM"
        let prompt = CoachPrompt.make(memory: m, text: text, focus: .analiz, mode: .analysis)
        XCTAssertLessThan(prompt.count, 3900)
        XCTAssertEqual(prompt.components(separatedBy: text).count - 1, 1)
    }
    func testEveryAreaHasThreeConcreteOfflineSteps() {
        for area in StudyArea.allCases {
            let steps = LessonLibrary.steps(for: area)
            XCTAssertEqual(steps.count, 3)
            XCTAssertTrue(steps.allSatisfy { !$0.prompt.isEmpty && !$0.instruction.isEmpty })
        }
    }
    func testMalformedSessionStepCannotEnterTheUI() throws {
        var m = fresh(); try ProgressEngine.start(&m, taskID: "voice", at: date())
        m.session?.stepIndex = -1
        let data = try JSONEncoder().encode(m)
        XCTAssertThrowsError(try JSONDecoder().decode(JarvisMemory.self, from: data))
    }
    func testMalformedRecallLevelIsRejected() throws {
        var m = fresh()
        var card = RecallCard(question: "Soru", answer: "Cevap", dueDay: "2026-10-18")
        card.level = -2; m.recallCards = [card]
        XCTAssertThrowsError(try JSONDecoder().decode(JarvisMemory.self, from: JSONEncoder().encode(m)))
    }
    func testMidnightPreservesDraftAnswersWithoutCallingThemCompleted() throws {
        var m = fresh(); try ProgressEngine.start(&m, taskID: "voice", at: date())
        m.session?.answers = ["Üç kelimeyi tekrar ettim."]; m.session?.stepIndex = 1
        ProgressEngine.rollover(&m, at: date("2026-10-19T06:00:00Z"))
        XCTAssertTrue(m.review.last?.contains("Üç kelimeyi tekrar ettim.") == true)
        XCTAssertEqual(m.completedTotal, 0); XCTAssertTrue(m.logs.isEmpty)
    }

}
