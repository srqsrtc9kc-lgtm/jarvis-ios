import SwiftUI
import Combine

@main
struct JarvisKocApp: App {
    @UIApplicationDelegateAdaptor(JarvisAppDelegate.self) private var delegate
    @StateObject private var store = JarvisStore()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).preferredColorScheme(.dark) }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: JarvisStore
    @Environment(\.scenePhase) private var phase
    var body: some View {
        TabView(selection: $store.selectedTab) {
            TodayView().tabItem { Label("Bugün", systemImage: "sun.max") }.tag(0)
            VoiceCoachView().tabItem { Label("JARVIS", systemImage: "waveform") }.tag(1)
            StatsScreen().tabItem { Label("Gelişim", systemImage: "chart.bar") }.tag(2)
            SettingsView().tabItem { Label("Ayarlar", systemImage: "gearshape") }.tag(3)
        }
        .tint(.cyan)
        .safeAreaInset(edge: .top) {
            if let warning = store.storageWarning {
                Text(warning).font(.caption).foregroundStyle(.orange).padding(10).frame(maxWidth: .infinity).background(.black)
            }
        }
        .sheet(isPresented: $store.showPractice) { PracticeView().environmentObject(store) }
        .alert("JARVIS", isPresented: Binding(get: { store.errorMessage != nil && store.selectedTab != 1 }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("Tamam") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .onAppear { store.updateForToday(); store.refreshReminders(); store.handleNotification() }
        .onReceive(NotificationCenter.default.publisher(for: .jarvisNotificationOpened)) { _ in store.handleNotification() }
        .onChange(of: phase) { _, value in
            if value == .active { store.updateForToday(); store.refreshReminders(); store.handleNotification() }
            else { store.pausePractice(); store.cancelReply() }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            guard phase == .active else { return }; store.updateForToday()
        }
    }
}

struct Panel<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.06), lineWidth: 1))
    }
}

struct TodayView: View {
    @EnvironmentObject private var store: JarvisStore
    @State private var undoTask: StudyTask?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("JARVIS  /  GELİŞİM KOÇUN").font(.caption.bold()).tracking(2).foregroundStyle(.cyan)
                    Text("Bir sonraki adımı\nat.").font(.system(size: 38, weight: .bold, design: .rounded))
                    Text("\(store.memory.dateKey) · \(store.tasks.reduce(0) { $0 + $1.minutes }) dakika · \(StudyCurriculum.generalCultureTopic(settings: store.memory.settings))")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Panel {
                        HStack(spacing: 20) {
                            ZStack {
                                Circle().stroke(.white.opacity(0.08), lineWidth: 8)
                                Circle().trim(from: 0, to: CGFloat(store.completedToday) / CGFloat(max(1, store.totalToday)))
                                    .stroke(.cyan, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                                Text("\(store.completedToday)/\(store.totalToday)").font(.title2.bold().monospacedDigit())
                            }.frame(width: 72, height: 72).accessibilityLabel("\(store.totalToday) görevden \(store.completedToday) tanesi tamamlandı olarak kaydedildi")
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Bugünün ilerlemesi").font(.headline)
                                Text("Tamamlamayı bir sonuç notuyla kaydet. Küçük ama gerçek bir çıktı üret.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let session = store.memory.session {
                        Button { store.showPractice = true } label: {
                            Label("Kaldığın yerden devam et · \(session.title)", systemImage: "play.circle.fill").frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.borderedProminent).tint(.cyan).foregroundStyle(.black)
                    }
                    ForEach(store.tasks) { task in
                        Panel {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label(task.time, systemImage: task.area.icon).font(.caption.bold()).foregroundStyle(.cyan)
                                    Spacer(); Text("\(task.minutes) dk").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    if task.done { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                }
                                Text(task.title).font(.headline)
                                Text(task.instructions).font(.footnote).foregroundStyle(.secondary)
                                if task.done {
                                    Button("Tamamlamayı geri al") { undoTask = task }.font(.caption).tint(.secondary)
                                } else {
                                    Button { store.openPractice(task.id) } label: {
                                        Label("Çalışmaya başla", systemImage: "arrow.up.right")
                                    }.buttonStyle(.bordered).tint(.cyan)
                                }
                            }
                        }
                    }
                    Text("Plan İstanbul saatine göre hazırlanır. Süre ve başlangıç saatini Ayarlar'dan değiştirebilirsin.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }
            .navigationTitle("Bugün").toolbarTitleDisplayMode(.inline)
            .confirmationDialog("Bu görevin tamamlanma kaydı ve sonuç notu kaldırılacak.", isPresented: Binding(get: { undoTask != nil }, set: { if !$0 { undoTask = nil } })) {
                Button("Tamamlamayı geri al", role: .destructive) { if let task = undoTask { store.undo(task.id) }; undoTask = nil }
                Button("Vazgeç", role: .cancel) { undoTask = nil }
            }
        }
    }
}

struct PracticeView: View {
    @EnvironmentObject private var store: JarvisStore
    @Environment(\.dismiss) private var dismiss
    @State private var answer = ""
    @State private var resultNote = ""
    @State private var discard = false
    var body: some View {
        NavigationStack {
            ScrollView {
                if let session = store.memory.session {
                    let steps = LessonLibrary.steps(for: session.area)
                    VStack(alignment: .leading, spacing: 18) {
                        Text(session.title).font(.title.bold())
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let seconds = Int(session.elapsed(at: context.date))
                            HStack {
                                Text(String(format: "%02d:%02d", seconds / 60, seconds % 60)).font(.system(size: 38, weight: .medium, design: .monospaced))
                                Text("/ \(session.targetMinutes) dk").foregroundStyle(.secondary)
                                Spacer()
                                Button { store.toggleTimer() } label: {
                                    Image(systemName: session.runningSince == nil ? "play.circle.fill" : "pause.circle.fill").font(.largeTitle)
                                }.accessibilityLabel(session.runningSince == nil ? "Sayacı başlat" : "Sayacı duraklat")
                            }
                        }
                        Text("Sayaç uygulama etkin değilken duraklar. Süre, dikkat veya beceri ölçümü değildir.").font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: Double(min(session.stepIndex, steps.count)), total: Double(steps.count))
                        if session.stepIndex < steps.count {
                            let step = steps[session.stepIndex]
                            Panel {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("ADIM \(session.stepIndex + 1) / \(steps.count)").font(.caption.bold()).foregroundStyle(.cyan)
                                    Text(step.title).font(.title2.bold())
                                    Text(step.instruction)
                                    Text(step.prompt).font(.headline)
                                }
                            }
                            TextField("Önce kendi cevabını yaz", text: $answer, axis: .vertical).lineLimit(4...8).textFieldStyle(.roundedBorder)
                            HStack {
                                if session.stepIndex > 0 { Button("Önceki") { store.previousStep(); loadAnswer() } }
                                Spacer()
                                Button("Kaydet ve ilerle") { store.saveStep(answer); loadAnswer() }
                                    .buttonStyle(.borderedProminent).disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        } else {
                            Panel {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Çalışma çıktın", systemImage: "text.badge.checkmark").font(.headline)
                                    ForEach(Array(session.answers.enumerated()), id: \.offset) { index, text in
                                        Text("\(index + 1). \(text)").font(.footnote).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Button("Yanıtları gözden geçir") { store.previousStep(); loadAnswer() }
                            TextField("Ne öğrendin, neyi geliştireceksin? (en az 12 karakter)", text: $resultNote, axis: .vertical)
                                .lineLimit(3...6).textFieldStyle(.roundedBorder)
                            Text("Bu kayıt senin beyanındır. AI otomatik başarı puanı vermeyecek.").font(.caption).foregroundStyle(.secondary)
                            Button("Sonucu kaydet ve tamamla") { store.finishPractice(resultNote) }
                                .buttonStyle(.borderedProminent).disabled(resultNote.trimmingCharacters(in: .whitespacesAndNewlines).count < 12)
                        }
                        Button("Bu alanı JARVIS ile konuş") {
                            store.focus = session.area; store.coachMode = session.area == .satis ? .roleplay : .exercise
                            store.selectedTab = 1; dismiss()
                        }.buttonStyle(.bordered)
                        Button("Çalışma taslağını bırak", role: .destructive) { discard = true }.font(.footnote)
                    }.padding(20)
                } else { ContentUnavailableView("Açık çalışma yok", systemImage: "checkmark.circle", description: Text("Bugünkü plandan bir çalışma seç.")) }
            }
            .navigationTitle("Odak oturumu").toolbarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() } } }
            .onAppear { loadAnswer() }
            .onDisappear { store.pausePractice() }
            .confirmationDialog("Bu çalışmanın kaydedilmiş adımları silinecek.", isPresented: $discard) {
                Button("Taslağı bırak", role: .destructive) { store.abandonPractice() }
            }
        }.tint(.cyan)
    }
    private func loadAnswer() {
        guard let session = store.memory.session else { return }
        answer = session.stepIndex < session.answers.count ? session.answers[session.stepIndex] : ""
    }
}
