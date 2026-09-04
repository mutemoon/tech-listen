import UIKit

/// Concrete implementation of the feedback layer providing restrained haptics.
@MainActor
public final class HapticFeedbackService: FeedbackServiceProtocol {
    private let config: any ConfigurationServiceProtocol

    public init(config: any ConfigurationServiceProtocol) {
        self.config = config
    }

    public func triggerTap() {
        guard config.hapticEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    public func triggerActionSuccess() {
        guard config.hapticEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    public func triggerActionFailure() {
        guard config.hapticEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    public func triggerImpact() {
        guard config.hapticEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}
