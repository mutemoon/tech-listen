import SwiftUI

/// Defines the selectable navigation destinations for the bottom glass bar.
public enum TabItem: String, CaseIterable, Identifiable, Sendable {
    case episodes
    case player
    case settings

    public var id: String { rawValue }

    @MainActor
    public var title: String {
        switch self {
        case .episodes:
            return LanguageManager.shared.current == .chinese ? "节目" : "Episodes"
        case .player:
            return LanguageManager.shared.current == .chinese ? "精听" : "Listen"
        case .settings:
            return LanguageManager.shared.string(.tabSettings)
        }
    }

    public var icon: String {
        switch self {
        case .episodes: return "list.bullet"
        case .player: return "play"
        case .settings: return "gearshape"
        }
    }

    public var selectedIcon: String {
        switch self {
        case .episodes: return "list.bullet"
        case .player: return "play"
        case .settings: return "gearshape.fill"
        }
    }
}
