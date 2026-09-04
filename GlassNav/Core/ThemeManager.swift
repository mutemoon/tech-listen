import SwiftUI

public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    public var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

@Observable
@MainActor
public final class ThemeManager {
    public static let shared = ThemeManager()
    public var current: AppTheme = .system

    public func cycle() {
        switch current {
        case .system: current = .light
        case .light: current = .dark
        case .dark: current = .system
        }
    }
}
