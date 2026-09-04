import Foundation

/// Abstraction for the cache layer managing data in memory and disk storage.
public protocol CacheServiceProtocol: Sendable {
    func set(data: Data, forKey key: String)
    func get(forKey key: String) -> Data?
    func clearAll()
    func cachedItemCount() -> Int
    func formattedCacheSize() -> String
}
