import SwiftUI

/// Root canvas view hosting the main screen content with ambient glass backdrop and shaped navigation bar.
struct RootContentView: View {
    @Environment(\.appContainer) private var container
    var body: some View {
        ZStack(alignment: .bottom) {
            // Ambient backdrop for glass refraction
            ambientBackdrop
                .ignoresSafeArea()

            // Main Active Page View
            Group {
                switch container.appState.selectedTab {
                case .episodes:
                    HomeView(onSelectEpisode: { episode in
                        container.appState.openEpisode(episode)
                    })
                case .player:
                    PlayerHomeView(episode: container.appState.activeEpisode, onBackToEpisodes: {
                        withAnimation(DesignSystem.LiquidGlass.interactiveSpring) {
                            container.appState.selectedTab = .episodes
                        }
                    })
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating Shaped Bottom Glass Tab Bar
            ShapedGlassTabBar(
                selectedTab: Binding(
                    get: { container.appState.selectedTab },
                    set: { container.appState.selectedTab = $0 }
                ),
                isPlaying: container.audioPlayer.isPlaying,
                onPlayPauseTap: {
                    container.appState.togglePlayCurrentSentence(using: container.audioPlayer)
                }
            )
        }
        .task {
            await container.appState.restoreInitialState(using: container.episodeRepository)
        }
        .preferredColorScheme(.dark)
    }

    /// Ambient lighting backdrop specifically balanced for Liquid Glass refraction and depth.
    private var ambientBackdrop: some View {
        ZStack {
            Color.black

            // Top-leading subtle sapphire orb
            Circle()
                .fill(Color(red: 0.12, green: 0.38, blue: 0.92).opacity(0.18))
                .blur(radius: 100)
                .frame(width: 340, height: 340)
                .offset(x: -120, y: -220)

            // Center-trailing soft violet orb
            Circle()
                .fill(Color(red: 0.35, green: 0.18, blue: 0.80).opacity(0.15))
                .blur(radius: 110)
                .frame(width: 320, height: 320)
                .offset(x: 130, y: 80)

            // Bottom subtle azure luminescence providing refraction glow under the tab bar
            Circle()
                .fill(Color(red: 0.10, green: 0.45, blue: 0.85).opacity(0.14))
                .blur(radius: 95)
                .frame(width: 300, height: 300)
                .offset(x: 0, y: 380)
        }
    }
}

/// Standardized page header ensuring pixel-perfect identical position, typography, and alignment across all tabs.
public struct PageHeaderView<RightContent: View>: View {
    public let title: String
    @ViewBuilder public var rightContent: () -> RightContent

    public init(title: String, @ViewBuilder rightContent: @escaping () -> RightContent) {
        self.title = title
        self.rightContent = rightContent
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(height: 38, alignment: .leading)

            Spacer(minLength: 0)

            rightContent()
                .frame(height: 38)
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

public extension PageHeaderView where RightContent == EmptyView {
    init(title: String) {
        self.init(title: title) {
            EmptyView()
        }
    }
}
