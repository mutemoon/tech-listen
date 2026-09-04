import SwiftUI

/// Observable implementation of the configuration layer managing all dynamic parameters.
@Observable
@MainActor
public final class AppConfigurationService: ConfigurationServiceProtocol {
    public var pageSize: Int = 3
    public var cardCornerRadius: CGFloat = 22.0
    public var glassStrokeWidth: CGFloat = 1.0
    public var glassShadowRadius: CGFloat = 14.0
    public var animationDuration: Double = 0.35
    public var hapticEnabled: Bool = true

    public init() {}

    public func resetToDefaults() {
        self.pageSize = 3
        self.cardCornerRadius = 22.0
        self.glassStrokeWidth = 1.0
        self.glassShadowRadius = 14.0
        self.animationDuration = 0.35
        self.hapticEnabled = true
    }
}
