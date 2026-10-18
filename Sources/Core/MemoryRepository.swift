import Foundation

/// Atomic local file + last valid backup. Never replaces a corrupt profile with empty data.
final class MemoryRepository {
    let fileURL: URL
    let backupURL: URL
    init(directory: URL) {
        fileURL = directory.appendingPathComponent("jarvis-memory-v4.json")
        backupURL = directory.appendingPathComponent("jarvis-memory-backup.json")
    }
    func load() throws -> (memory: JarvisMemory?, recovered: Bool) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) && !fm.fileExists(atPath: backupURL.path) { return (nil, false) }
        if fm.fileExists(atPath: fileURL.path) {
            do { return (try decode(Data(contentsOf: fileURL)), false) }
            catch MemoryError.newerVersion { throw MemoryError.newerVersion }
            catch { /* Try the last valid copy; leave the original bytes untouched. */ }
        }
        if let data = try? Data(contentsOf: backupURL), let value = try? decode(data) { return (value, true) }
        throw MemoryError.invalidData
    }
    func decode(_ data: Data) throws -> JarvisMemory {
        guard data.count <= 10_000_000 else { throw MemoryError.invalidData }
        return try JSONDecoder().decode(JarvisMemory.self, from: data)
    }
    func save(_ memory: JarvisMemory) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try export(memory)
        guard data.count <= 10_000_000 else { throw MemoryError.invalidData }
        if let old = try? Data(contentsOf: fileURL), (try? decode(old)) != nil {
            try write(old, to: backupURL)
        }
        try write(data, to: fileURL)
        if !fm.fileExists(atPath: backupURL.path) { try write(data, to: backupURL) }
    }
    func export(_ memory: JarvisMemory) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(memory)
    }
    private func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
