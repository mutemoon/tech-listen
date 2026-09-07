import SwiftUI

/// Unified design system tokens for Listen Tech / 科听.
public enum DesignSystem {
    public enum Brand {
        public static let chineseName = "科听"
        public static let englishName = "Listen Tech"
        public static let logoIcon = "headphones"
    }

    public enum CornerRadius {
        public static let small: CGFloat = 10
        public static let medium: CGFloat = 16
        public static let card: CGFloat = 22
        public static let full: CGFloat = 999
    }

    public enum Spacing {
        public static let tight: CGFloat = 6
        public static let standard: CGFloat = 12
        public static let relaxed: CGFloat = 16
        public static let section: CGFloat = 24
    }

    public enum Glass {
        public static let strokeWidth: CGFloat = 1.0
        public static let shadowRadius: CGFloat = 16.0
    }

    public enum LiquidGlass {
        public static let containerSpacing: CGFloat = 12.0
        public static let barSpacing: CGFloat = 8.0
        public static let barHeight: CGFloat = 52.0
        public static let cardCornerRadius: CGFloat = 22.0
        public static let tokenCornerRadius: CGFloat = 12.0
        public static let specularStrokeWidth: CGFloat = 1.0
        public static let interactiveSpring = Animation.spring(response: 0.28, dampingFraction: 0.78)
        public static let morphSpring = Animation.spring(response: 0.34, dampingFraction: 0.82)
    }
}

