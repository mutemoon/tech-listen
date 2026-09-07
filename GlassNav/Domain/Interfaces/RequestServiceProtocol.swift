import Foundation

/// Abstraction for the request layer executing network data transfers.
/// Isolates HTTP/network transport mechanisms, enabling mocking and clean testing.
public protocol RequestServiceProtocol: Sendable {
    /// Performs an asynchronous data fetch for the specified URL request.
    func data(for request: URLRequest) async throws -> (Data, URLResponse)

    /// Convenience fetch for a simple URL.
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension RequestServiceProtocol {
    public func data(from url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        return try await data(for: request)
    }
}
