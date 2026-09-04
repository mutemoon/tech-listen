import SwiftUI

/// Abstraction for the configuration layer managing all dynamic parameters.
/// Every numeric parameter in the app is driven by this protocol without hardcoding.
@MainActor
public protocol ConfigurationServiceProtocol: AnyObject, Sendable {
    var pageSize: Int { get set }
    var cardCornerRadius: CGFloat { get set }
    var glassStrokeWidth: CGFloat { get set }
    var glassShadowRadius: CGFloat { get set }
    var animationDuration: Double { get set }
    var hapticEnabled: Bool { get set }

    func resetToDefaults()
}
