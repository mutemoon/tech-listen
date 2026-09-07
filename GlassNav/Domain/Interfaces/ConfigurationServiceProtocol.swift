import SwiftUI

/// Abstraction for the configuration layer managing dynamic parameters.
@MainActor
public protocol ConfigurationServiceProtocol: AnyObject, Sendable {
    var language: Language { get set }
    var pageSize: Int { get set }
    var hapticEnabled: Bool { get set }

    func resetToDefaults()
}
