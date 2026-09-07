import Foundation

/// Concrete production implementation of RequestServiceProtocol backed by URLSession.
public final class URLSessionRequestService: RequestServiceProtocol, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }
}
