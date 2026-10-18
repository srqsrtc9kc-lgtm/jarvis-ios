import SwiftUI
import Combine
import AVFoundation

struct VoiceCoachView: View {
    @EnvironmentObject private var store: JarvisStore
    @Environment(\.scenePhase) private var phase
    @AppStorage("jarvis-auto-voice") private var autoVoice = true
    @AppStorage("jarvis-active-nudges") private var activeNudges = true
    @AppStorage("jarvis-spoken-replies") private var spokenReplies = true
    @StateObject private var recognizer = LocalSpeech()
    @StateObject private var speaker = TurkishSpeaker()
    @State private var typed = ""
    @State private var handsFree = false
    @State private var armed = false
    @State private var visible = false
    @State private var committing = false
    @State private var voiceEpoch = UUID()
    @State private var lastChange = Date()
    @State private var lastNudgeCheck = Date()
    private var canListen: Bool { visible && phase == .active && !store.showPractice && !store.isThinking }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: speaker.speaking ? "waveform" : "sparkle").foregroundStyle(.cyan).font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(speaker.speaking ? "JARVIS konuşuyor" : recognizer.isListening ? "Seni dinliyorum" : "Birlikte çalışalım").font(.headline)
                        Text(store.modelStatus).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { stopAll() } label: { Image(systemName: "stop.circle").font(.title2) }.accessibilityLabel("Sesi, mikrofonu ve yanıtı durdur")
                }
                HStack {
                    Picker("Çalışma alanı", selection: $store.focus) { ForEach(StudyArea.allCases) { Text($0.rawValue).tag($0) } }
                    Spacer()
                    Picker("Koçluk modu", selection: $store.coachMode) { ForEach(CoachMode.allCases) { Text($0.rawValue).tag($0) } }
                }.font(.caption)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if store.recentMessages.isEmpty {
                                Panel {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Önce sen düşün.").font(.title2.bold())
                                        Text("Bir fikrini, zorlandığın noktayı veya çalışmanı yaz. Birlikte sınayalım.").foregroundStyle(.secondary)
                                        Button("İlk soruyu sor") { Task { await submit("Bu alanda önce kendi fikrimi üretmemi sağlayan tek bir soru sor.") } }.buttonStyle(.bordered)
                                    }
                                }
                            }
                            ForEach(store.recentMessages) { message in
                                HStack {
                                    if message.fromUser { Spacer(minLength: 32) }
                                    VStack(alignment: .leading, spacing: 5) {
                                        if let source = message.source { Text(source).font(.caption2.bold()).foregroundStyle(.cyan) }
                                        Text(message.text).textSelection(.enabled)
                                    }.padding(14).background(message.fromUser ? Color.cyan.opacity(0.15) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                                    if !message.fromUser { Spacer(minLength: 32) }
                                }.id(message.id)
                            }
                            if store.isThinking {
                                HStack { ProgressView(); Text("Düşünüyorum…").foregroundStyle(.secondary); Button("İptal") { stopAll() } }.id("thinking")
                            }
                        }
                    }
                    .onChange(of: store.recentMessages.last?.id) { _, id in
                        if let id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                    }
                }
                if recognizer.isListening || recognizer.isStarting {
                    Text(recognizer.isStarting ? "Mikrofon hazırlanıyor…" : recognizer.transcript.isEmpty ? "Konuşabilirsin…" : recognizer.transcript)
                        .font(.footnote).lineLimit(4).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                        .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                if let message = recognizer.errorMessage ?? store.errorMessage {
                    HStack(alignment: .top) {
                        Text(message).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                        Button { recognizer.errorMessage = nil; store.errorMessage = nil } label: { Image(systemName: "xmark.circle") }
                    }
                }
                Toggle("Eller serbest · başlatmak için mikrofona dokun", isOn: $handsFree).font(.caption)
                    .onChange(of: handsFree) { _, value in if !value { armed = false } }
                HStack(alignment: .bottom, spacing: 10) {
                    Button {
                        Task {
                            if recognizer.isListening { await commitRecording() }
                            else if recognizer.isStarting { stopAll() }
                            else {
                                speaker.stop(); armed = handsFree
                                guard canListen else { return }; await recognizer.start()
                            }
                        }
                    } label: {
                        Image(systemName: recognizer.isListening ? "stop.circle.fill" : "mic.circle.fill").font(.system(size: 44))
                            .foregroundStyle(recognizer.isListening ? .red : .cyan)
                    }.disabled(store.isThinking || committing)
                    .accessibilityLabel(recognizer.isListening ? "Konuşmayı bitir ve gönder" : "Mikrofonu aç")
                    TextField("Düşünceni yaz…", text: $typed, axis: .vertical).lineLimit(1...4).textFieldStyle(.roundedBorder)
                        .submitLabel(.send).onSubmit { Task { await submit(typed) } }
                    Button { Task { await submit(typed) } } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }
                        .disabled(store.isThinking || typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Mesajı gönder")
                }
            }.padding(16)
            .navigationTitle("JARVIS").toolbarTitleDisplayMode(.inline)
            .onAppear {
                visible = true; lastNudgeCheck = Date()
                recognizer.onFinal = { text in Task { await acceptVoice(text) } }
                speaker.onFinished = { Task { await restartIfAllowed() } }
                if autoVoice { greet() }
            }
            .onDisappear { visible = false; stopAll(); recognizer.onFinal = nil; speaker.onFinished = nil }
            .onChange(of: phase) { _, value in
                if value == .background || (value == .inactive && !recognizer.isStarting) { stopAll() }
                else if value == .active && visible { lastNudgeCheck = Date(); if autoVoice { greet() } }
            }
            .onChange(of: store.showPractice) { _, presented in if presented { stopAll() } }
            .onChange(of: store.focus) { _, _ in stopAll() }
            .onChange(of: store.coachMode) { _, _ in stopAll() }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in stopAll() }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
                if recognizer.isListening { stopAll() }
            }
            .onChange(of: recognizer.transcript) { _, value in if !value.isEmpty { lastChange = Date() } }
            .onReceive(Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()) { date in
                if handsFree && armed && canListen && recognizer.isListening && !committing &&
                    !recognizer.transcript.isEmpty && date.timeIntervalSince(lastChange) > store.memory.settings.silenceSeconds {
                    Task { await commitRecording() }
                }
            }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in nudge(date) }
        }
    }
    private func stopAll() {
        voiceEpoch = UUID(); armed = false; committing = false
        recognizer.stopSilently(); speaker.stop(); store.cancelReply()
    }
    private func restartIfAllowed() async {
        guard handsFree, armed, canListen, !speaker.speaking, !committing else { return }
        await recognizer.start()
    }
    private func commitRecording() async {
        guard !committing else { return }; committing = true
        let token = voiceEpoch
        let text = await recognizer.stop()
        guard token == voiceEpoch else { return }
        await submit(text); committing = false
        if !speaker.speaking { await restartIfAllowed() }
    }
    private func acceptVoice(_ text: String) async {
        guard canListen, !committing else { return }
        if handsFree { await submit(text) }
        else { typed = text } // Natural task end leaves one-shot speech reviewable before sending.
    }
    private func submit(_ value: String) async {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, visible, phase == .active, !store.isThinking else { return }
        let token = voiceEpoch
        recognizer.stopSilently(); speaker.stop(); typed = ""
        let answer = await store.ask(clean, focus: store.focus, mode: store.coachMode)
        guard token == voiceEpoch, visible, phase == .active, !store.showPractice else { return }
        if let answer, spokenReplies { speaker.speak(answer) }
        else if answer != nil { await restartIfAllowed() }
    }
    private func greet() {
        guard canListen, !speaker.speaking, !recognizer.isListening, !recognizer.isStarting,
              (8...21).contains(store.memory.settings.calendar.component(.hour, from: Date())) else { return }
        let key = ProactiveEngine.greetingKey(settings: store.memory.settings)
        guard UserDefaults.standard.string(forKey: "jarvis-last-greeting") != key else { return }
        UserDefaults.standard.set(key, forKey: "jarvis-last-greeting")
        speaker.speak(ProactiveEngine.greeting(tasks: store.tasks, settings: store.memory.settings))
    }
    private func nudge(_ date: Date) {
        defer { lastNudgeCheck = date }
        guard activeNudges, canListen, !speaker.speaking, !recognizer.isListening, store.memory.session == nil else { return }
        let cal = store.memory.settings.calendar
        let time = cal.dateComponents([.hour, .minute], from: date)
        guard (8...21).contains(time.hour ?? 0) else { return }
        guard let task = store.tasks.first(where: {
            guard !$0.done else { return false }
            let p = $0.time.split(separator: ":").compactMap { Int($0) }
            guard p.count == 2, let due = cal.date(bySettingHour: p[0], minute: p[1], second: 0, of: date) else { return false }
            return due > lastNudgeCheck && due <= date
        }) else { return }
        let key = "\(store.memory.dateKey)-\(task.id)"
        guard UserDefaults.standard.string(forKey: "jarvis-last-nudge") != key else { return }
        UserDefaults.standard.set(key, forKey: "jarvis-last-nudge")
        speaker.speak("\(task.title) için \(task.minutes) dakika ayırma zamanı. Hazır olduğunda Bugün ekranından başlayabilirsin.")
    }
}
