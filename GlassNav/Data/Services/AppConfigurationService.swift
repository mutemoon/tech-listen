import SwiftUI

/// Observable implementation of the configuration layer managing dynamic parameters.
@Observable
@MainActor
public final class AppConfigurationService: ConfigurationServiceProtocol {
    public var language: Language {
        get { LanguageManager.shared.current }
        set { LanguageManager.shared.current = newValue }
    }
    public var pageSize: Int = 20
    public var hapticEnabled: Bool = true

    public init() {}

    public func resetToDefaults() {
        self.language = .chinese
        self.pageSize = 20
        self.hapticEnabled = true
    }
}
