import SwiftUI

/// Defines the selectable navigation destinations for the bottom glass bar.
enum TabItem: String, CaseIterable, Identifiable, Sendable {
    case home
    case settings

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .home:
            return LanguageManager.shared.string(.tabHome)
        case .settings:
            return LanguageManager.shared.string(.tabSettings)
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
