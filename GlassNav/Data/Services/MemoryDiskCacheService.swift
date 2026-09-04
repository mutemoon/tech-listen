import Foundation

/// Concrete implementation of the cache layer utilizing in-memory NSCache and disk directory.
public final class MemoryDiskCacheService: CacheServiceProtocol, @unchecked Sendable {
    private let memoryCache = NSCache<NSString, NSData>()
    private let lock = NSLock()
    private var keys: Set<String> = []
    private var inMemoryBytes: Int64 = 0

    private var downloadsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("downloads", isDirectory: true)
    }

    private var documentDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    public init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024
    }

    public func set(data: Data, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        keys.insert(key)
        inMemoryBytes += Int64(data.count)
    }

    public func get(forKey key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return memoryCache.object(forKey: key as NSString) as Data?
    }

    public func clearAll() {
        lock.lock()
        memoryCache.removeAllObjects()
        keys.removeAll()
        inMemoryBytes = 0
        lock.unlock()
    }

    public func cachedItemCount() -> Int {
        var count = 0
        if let downloads = downloadsDirectory,
           let files = try? FileManager.default.contentsOfDirectory(at: downloads, includingPropertiesForKeys: nil) {
            count += files.count
        }
        lock.lock()
        count += keys.count
        lock.unlock()
        return count
    }

    public func formattedCacheSize() -> String {
        let total = totalDiskAndMemoryBytes()
        if total <= 0 {
            return "0 MB"
        }
        if total >= 1024 * 1024 * 1024 {
            let gb = Double(total) / Double(1024 * 1024 * 1024)
            return String(format: "%.2f GB", gb)
        } else if total >= 1024 * 1024 {
            let mb = Double(total) / Double(1024 * 1024)
            return String(format: "%.1f MB", mb)
        } else {
            let kb = Double(total) / 1024.0
            return String(format: "%.0f KB", max(1.0, kb))
        }
    }

    private func totalDiskAndMemoryBytes() -> Int64 {
        var total: Int64 = 0

        // Calculate size of downloads directory
        if let downloads = downloadsDirectory, FileManager.default.fileExists(atPath: downloads.path) {
            if let enumerator = FileManager.default.enumerator(at: downloads, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        total += Int64(fileSize)
                    }
                }
            }
        }

        // Calculate size of cache JSON files in Document directory
        if let docs = documentDirectory {
            let cacheFile = docs.appendingPathComponent("episodes_cache.json")
            if FileManager.default.fileExists(atPath: cacheFile.path),
               let attrs = try? FileManager.default.attributesOfItem(atPath: cacheFile.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }

        lock.lock()
        total += inMemoryBytes
        lock.unlock()

        return total
    }
}
