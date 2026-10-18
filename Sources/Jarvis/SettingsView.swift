import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsView: View {
    @EnvironmentObject private var store: JarvisStore
    @Environment(\.openURL) private var openURL
    @AppStorage("jarvis-auto-voice") private var autoVoice = true
    @AppStorage("jarvis-active-nudges") private var activeNudges = true
    @AppStorage("jarvis-spoken-replies") private var spokenReplies = true
    @State private var notes = ""
    @State private var status = ""
    @State private var backup = BackupDocument(data: Data())
    @State private var exporting = false
    @State private var importing = false
    @State private var imported: JarvisMemory?
    @State private var confirmRestore = false
    @State private var confirmClear = false
    @State private var notificationsBusy = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Günlük plan") {
                    Picker("Çalışma süresi", selection: Binding(get: { store.memory.settings.dailyMinutes }, set: { value in
                        var settings = store.memory.settings; settings.dailyMinutes = value; store.updateSettings(settings)
                    })) { Text("30 dakika · kısa").tag(30); Text("60 dakika · dengeli").tag(60); Text("180 dakika · yoğun").tag(180) }
                    Stepper("Başlangıç: \(store.memory.settings.startHour):00", value: Binding(get: { store.memory.settings.startHour }, set: { value in
                        var settings = store.memory.settings; settings.startHour = value; store.updateSettings(settings)
                    }), in: 8...12)
                    Text("Değişiklikler sonraki günün planına uygulanır. Saat dilimi: İstanbul. Bildirimler 08:00–21:59 arasındadır.").font(.caption)
                    Button("Başlanmamış bugünkü planı yenile") { store.rebuildUnstartedPlan() }
                }
                Section("Sesli kullanım") {
                    Toggle("Açılışta JARVIS konuşsun", isOn: $autoVoice)
                    Toggle("Yanıtları seslendir", isOn: $spokenReplies)
                    Toggle("JARVIS ekranında çalışma saatini hatırlat", isOn: $activeNudges)
                    Stepper("Konuşma sonu bekleme: \(store.memory.settings.silenceSeconds, specifier: "%.1f") sn", value: Binding(get: { store.memory.settings.silenceSeconds }, set: { value in
                        var settings = store.memory.settings; settings.silenceSeconds = value; store.updateSettings(settings)
                    }), in: 2...6, step: 0.5)
                    Text("Eller serbest modunu sohbet ekranından açıp mikrofona dokunarak başlatırsın. Ekran kapanınca veya arama gelince dinleme durur; tekrar sen başlatırsın.").font(.caption)
                }
                Section("Bildirimler") {
                    Button("7 günlük çalışma bildirimlerini aç / yenile") {
                        notificationsBusy = true
                        Task {
                            defer { notificationsBusy = false }
                            do { try await JarvisNotifications.shared.enable(memory: store.memory); status = "Gelecek 7 günün bildirimleri güncellendi." }
                            catch { status = error.localizedDescription }
                        }
                    }.disabled(notificationsBusy)
                    Button("Çalışma bildirimlerini kapat") {
                        notificationsBusy = true
                        Task { await JarvisNotifications.shared.disable(); status = "Bildirimler kapatıldı."; notificationsBusy = false }
                    }.disabled(notificationsBusy)
                    Text("Bildirim alarm değildir. Telefonun sessiz/Odak ayarı teslimi etkileyebilir. Uygulamayı açtığında 7 günlük pencere yenilenir; uzun süre açmazsan bildirimler biter.").font(.caption)
                    if !store.reminderStatus.isEmpty { Text(store.reminderStatus).font(.caption).foregroundStyle(.orange) }
                }
                Section("Koçun bilmesini istediğin") {
                    TextEditor(text: $notes).frame(minHeight: 100)
                    Text("Hedeflerini, zorlandığın davranışları ve tercihlerini yaz. En fazla 1.300 karakter kaydedilir.").font(.caption)
                    Button("Notları kaydet") { store.saveNotes(notes); notes = store.notes; status = "Notlar kaydedildi." }
                }
                Section("Yedek ve kayıtlar") {
                    Button("Yedeği dosyaya aktar") {
                        do { backup = BackupDocument(data: try store.exportData()); exporting = true }
                        catch { status = error.localizedDescription }
                    }
                    Button("Yedekten geri yükle") { importing = true }
                    Text("Dışa aktarılan JSON; konuşmaları, çalışma notlarını ve gelişim kayıtlarını içerir. Dosyayı güvendiğin yerde sakla. Geri yükleme mevcut kaydın yerini alır.").font(.caption)
                    Button("Yalnızca sohbet geçmişini sil", role: .destructive) { confirmClear = true }
                }
                Section("Durum ve gizlilik") {
                    Label(store.modelStatus, systemImage: "cpu")
                    Text("Uygulama AI veya analitik sunucusuna bağlanmaz. Apple'ın model ve ses paketi indirmeleri iOS tarafından yönetilir. Uygulama verileri cihazda saklanır; iOS cihaz yedeğine dahil olabilir.").font(.caption)
                    Text("Kilit ekranında sürekli dinleme, otomatik canlı konuşma, canlı internet araştırması ve gerçek alarm bu sürümde yoktur.").font(.caption)
                    Button("iPhone uygulama ayarlarını aç") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                    Text("JARVIS 0.4.0 · Kişisel gelişim koçu").font(.caption).foregroundStyle(.secondary)
                }
                if !status.isEmpty { Section { Text(status).foregroundStyle(.cyan) } }
            }
            .navigationTitle("Ayarlar").onAppear { notes = store.notes }
            .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "JARVIS-Yedek-\(store.memory.dateKey)") { result in
                switch result { case .success: status = "Yedek dosyası kaydedildi."; case .failure(let error): status = error.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 10_000_000 { throw MemoryError.invalidData }
                    imported = try store.validateImport(Data(contentsOf: url)); confirmRestore = true
                } catch { status = "Geri yükleme yapılamadı: \(error.localizedDescription)" }
            }
            .confirmationDialog("Yedek, mevcut konuşma ve gelişim kayıtlarının yerini alacak. Önce dışa aktardıysan devam et.", isPresented: $confirmRestore) {
                Button("Yedeği geri yükle", role: .destructive) {
                    do { if let imported { try store.restore(imported); notes = store.notes; status = "Yedek geri yüklendi." } }
                    catch { status = error.localizedDescription }; imported = nil
                }
                Button("Vazgeç", role: .cancel) { imported = nil }
            }
            .confirmationDialog("Sohbet geçmişi silinsin mi? Çalışma kayıtları korunur.", isPresented: $confirmClear) {
                Button("Sohbeti sil", role: .destructive) { store.clearHistory(); status = "Sohbet geçmişi silindi." }
            }
        }
    }
}
