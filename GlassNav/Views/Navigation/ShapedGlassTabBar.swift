import SwiftUI

public extension Notification.Name {
    static let scrollToTopRequested = Notification.Name("scrollToTopRequested")
}

/// Shaped bottom navigation bar with iOS 26 Liquid Glass container and morphing center slot.
public struct ShapedGlassTabBar: View {
    @Environment(\.appContainer) private var container
    @Binding public var selectedTab: TabItem
    public var isPlaying: Bool
    public var onPlayPauseTap: () -> Void
    @Namespace private var tabNamespace

    public init(
        selectedTab: Binding<TabItem>,
        isPlaying: Bool,
        onPlayPauseTap: @escaping () -> Void
    ) {
        self._selectedTab = selectedTab
        self.isPlaying = isPlaying
        self.onPlayPauseTap = onPlayPauseTap
    }

    private let barHeight: CGFloat = 48

    public var body: some View {
        AdaptiveGlassContainer(spacing: DesignSystem.LiquidGlass.barSpacing) {
            HStack(spacing: 0) {
                // 节目
                tabButton(title: TabItem.episodes.title, tab: .episodes)
                    .frame(maxWidth: .infinity)

                // Center slot (text "精听" when non-player; play button when on player)
                centerSlot
                    .frame(maxWidth: .infinity)

                // 设置
                tabButton(title: TabItem.settings.title, tab: .settings)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: barHeight)
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.12), location: 0.0),
                                    .init(color: .white.opacity(0.03), location: 0.5),
                                    .init(color: .white.opacity(0.10), location: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 0.5)
                }
                .shadow(color: Color.black.opacity(0.20), radius: 8, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
                .opacity(selectedTab == .player ? 0 : 1)
                .animation(DesignSystem.LiquidGlass.interactiveSpring, value: selectedTab == .player)
            }
        }
        .animation(DesignSystem.LiquidGlass.morphSpring, value: selectedTab)
    }

    private var centerSlot: some View {
        Group {
            if selectedTab == .player {
                Button {
                    container.feedbackService.triggerImpact()
                    onPlayPauseTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: 48, height: 48)

                        Circle()
                            .strokeBorder(Color.white.opacity(0.88), lineWidth: 1.5)
                            .frame(width: 48, height: 48)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(x: isPlaying ? 0 : 1.2)
                    }
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
                }
                .buttonStyle(BouncyScaleButtonStyle())
                .accessibilityLabel(isPlaying ? "暂停" : "播放")
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                tabButton(title: TabItem.player.title, tab: .player)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tabButton(title: String, tab: TabItem) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            container.feedbackService.triggerTap()
            if isSelected && tab == .episodes {
                NotificationCenter.default.post(name: .scrollToTopRequested, object: nil)
            } else {
                withAnimation(DesignSystem.LiquidGlass.interactiveSpring) {
                    selectedTab = tab
                }
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.48))
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct BouncyScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
