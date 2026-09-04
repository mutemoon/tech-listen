import Foundation

/// Abstraction for the feedback layer providing restrained micro-interactions and haptics.
@MainActor
public protocol FeedbackServiceProtocol: AnyObject, Sendable {
    func triggerTap()
    func triggerActionSuccess()
    func triggerActionFailure()
    func triggerImpact()
}

