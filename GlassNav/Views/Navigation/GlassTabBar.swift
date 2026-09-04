import SwiftUI

public extension Notification.Name {
    static let scrollToTopRequested = Notification.Name("scrollToTopRequested")
}

/// Floating bottom navigation bar with fluid glassmorphism and spring transition.
struct GlassTabBar: View {
    @Environment(\.appContainer) private var container
    @Binding var selectedTab: TabItem
    @Namespace private var animationNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TabItem.allCases) { tab in
                GlassTabItem(
                    item: tab,
                    isSelected: selectedTab == tab,
                    namespace: animationNamespace
                ) {
                    if selectedTab == tab {
                        if tab == .home {
                            container.feedbackService.triggerTap()
                            NotificationCenter.default.post(name: .scrollToTopRequested, object: nil)
                        }
                    } else {
                        container.feedbackService.triggerTap()
                        withAnimation(.snappy(
                            duration: container.configurationService.animationDuration,
                            extraBounce: 0.06
                        )) {
                            selectedTab = tab
                        }
                    }
                }
            }
        }
        .padding(6)
        .glassCapsule(
            material: .ultraThinMaterial,
            strokeWidth: container.configurationService.glassStrokeWidth,
            shadowRadius: container.configurationService.glassShadowRadius * 1.5
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

#Preview("Glass Tab Bar - Light") {
    ZStack(alignment: .bottom) {
        Color.gray.opacity(0.15).ignoresSafeArea()
        GlassTabBar(selectedTab: .constant(.home))
    }
    .environment(\.appContainer, ProductionContainer())
}

#Preview("Glass Tab Bar - Dark") {
    ZStack(alignment: .bottom) {
        Color.black.ignoresSafeArea()
        GlassTabBar(selectedTab: .constant(.settings))
    }
    .environment(\.appContainer, ProductionContainer())
    .preferredColorScheme(.dark)
}
