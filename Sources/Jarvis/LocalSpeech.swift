import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
final class LocalSpeech: ObservableObject {
    @Published var transcript = ""
    @Published private(set) var isListening = false
    @Published private(set) var isStarting = false
    @Published var errorMessage: String?
    var onFinal: ((String) -> Void)?
    private let engine = AVAudioEngine()
    private var tapInstalled = false
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr_TR"))
    private var generation = UUID()
    private var finishing = false
    private var receivedFinal = false
    private var expiry: Task<Void, Never>?

    func start() async {
        guard !isListening, !isStarting, !finishing else { return }
        stopSilently()
        let token = generation
        isStarting = true; transcript = ""; errorMessage = nil; receivedFinal = false
        let authorization = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard token == generation, !Task.isCancelled else { return }
        guard authorization == .authorized else { fail("Konuşma tanıma izni kapalı. Ayarlar'dan aç veya yazılı girişi kullan."); return }
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard token == generation, !Task.isCancelled else { return }
        guard microphone else { fail("Mikrofon izni kapalı. Yazılı giriş kullanılabilir."); return }
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            fail("Türkçe cihaz içi ses tanıma hazır değil. Yazabilirsin; buluta ses gönderilmez."); return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true
            self.request = request
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { fail("Mikrofon ses yolu hazır değil. Kulaklığı kontrol edip yeniden dene."); return }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            tapInstalled = true
            engine.prepare(); try engine.start()
            isStarting = false; isListening = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                // Extract immutable values before hopping onto the main actor.
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal ?? false
                let failure = error?.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self, token == self.generation else { return }
                    if let text { self.transcript = text }
                    if final {
                        self.receivedFinal = true
                        if !self.finishing {
                            let finalText = self.transcript
                            self.stopSilently(); self.onFinal?(finalText)
                        }
                    } else if let failure, !self.finishing {
                        self.fail("Ses tanıma durdu: \(failure)")
                    }
                }
            }
            expiry = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 55_000_000_000) } catch { return }
                guard let self, self.generation == token else { return }
                let final = await self.stop()
                self.onFinal?(final)
            }
        } catch { fail("Mikrofon başlatılamadı: \(error.localizedDescription)") }
    }
    func stop() async -> String {
        guard isListening, !finishing else { return "" }
        let token = generation
        finishing = true; isListening = false
        stopInput(); request?.endAudio(); task?.finish()
        // Wait for a final result, capped at 800 ms. Do not accept callbacks from an older turn.
        for _ in 0..<16 {
            if receivedFinal || generation != token { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard token == generation else { return "" }
        let result = transcript
        stopSilently(); return result
    }
    func stopSilently() {
        generation = UUID(); expiry?.cancel(); expiry = nil
        stopInput(); request?.endAudio(); task?.cancel(); task = nil; request = nil
        isListening = false; isStarting = false; finishing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func stopInput() {
        if engine.isRunning { engine.stop() }
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
    }
    private func fail(_ message: String) { stopSilently(); errorMessage = message }
}

@MainActor
final class TurkishSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var speaking = false
    var onFinished: (() -> Void)?
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    override init() {
        super.init(); synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = false
    }
    func speak(_ text: String) {
        stop()
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "tr-TR"); utterance.rate = 0.49
        currentUtterance = utterance; speaking = true; synthesizer.speak(utterance)
    }
    func stop() { currentUtterance = nil; synthesizer.stopSpeaking(at: .immediate); speaking = false }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.currentUtterance = nil; self.speaking = false; self.onFinished?()
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.currentUtterance = nil; self.speaking = false
        }
    }
}
