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
}
