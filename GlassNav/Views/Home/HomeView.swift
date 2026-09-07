import SwiftUI

private struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}


/// Main Home screen featuring pull-to-refresh, infinite scroll stream, and back-to-top navigation.
struct HomeView: View {
    @Environment(\.appContainer) private var container
    var onSelectEpisode: ((Episode) -> Void)? = nil
    @State private var viewModel: HomeViewModel?
    @State private var showBackToTop: Bool = false

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    PageHeaderView(title: TabItem.episodes.title) {
                        Color.clear.frame(width: 38, height: 38)
                    }

                    ZStack(alignment: .bottomTrailing) {
                        ScrollView(showsIndicators: false) {
                            Color.clear
                                .frame(height: 1)
                                .id("SCROLL_TO_TOP_ANCHOR")

                            LazyVStack(spacing: 16) {
                                if let vm = viewModel {
                                    ForEach(Array(vm.filteredEpisodes.enumerated()), id: \.element.id) { index, episode in
                                        HomeEpisodeCard(
                                            episode: episode,
                                            isDownloaded: vm.isDownloaded(episodeId: episode.id),
                                            downloadProgress: vm.downloadProgress(for: episode.id),
                                            downloadState: vm.downloadState(for: episode.id),
                                            onDownload: {
                                                Task {
                                                    await vm.triggerDownload(for: episode)
                                                }
                                            },
                                            onCancel: {
                                                vm.cancelDownload(for: episode.id)
                                            },
                                            onDelete: {
                                                vm.removeDownload(for: episode.id)
                                            }
                                        )
                                        .id(episode.id)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            container.feedbackService.triggerTap()
                                            container.appState.openEpisode(episode)
                                            onSelectEpisode?(episode)
                                        }
                                        .onAppear {
                                            Task {
                                                await vm.loadMoreIfNeeded(current: episode)
                                            }
                                        }
                                    }

                                    if vm.hasMore {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .padding(.vertical, 14)
                                            .onAppear {
                                                Task {
                                                    await vm.loadNextBatch()
                                                }
                                            }
                                            .task(id: vm.episodes.count) {
                                                if vm.filteredEpisodes.count < 5 && vm.hasMore {
                                                    await vm.loadNextBatch()
                                                }
                                            }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 6)
                            .padding(.bottom, 100)
                        }
                        .ignoresSafeArea(edges: .bottom)
                        .refreshable {
                            await viewModel?.refresh()
                        }
                        .onScrollThresholdCrossed(threshold: 80) { isScrolled in
                            withAnimation(DesignSystem.LiquidGlass.interactiveSpring) {
                                showBackToTop = isScrolled
                            }
                        }

                    // Floating Back to Top Button
                    if showBackToTop {
                        backToTopButton(proxy: scrollProxy)
                    }
                }
            }

            // Floating Frosted Glass Refresh Feedback Toast
            if let status = viewModel?.refreshStatus {
                refreshToastView(status: status)
                    .padding(.top, 56)
            }
        }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToTopRequested)) { _ in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    scrollProxy.scrollTo("SCROLL_TO_TOP_ANCHOR", anchor: .top)
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = HomeViewModel(
                        repository: container.episodeRepository,
                        downloadManager: container.downloadManager,
                        configService: container.configurationService,
                        feedbackService: container.feedbackService
                    )
                }
                await viewModel?.loadInitial()
            }
        }
    }

    /// Floating frosted glass back to top button
    private func backToTopButton(proxy: ScrollViewProxy) -> some View {
        Button {
            container.feedbackService.triggerTap()
            withAnimation(DesignSystem.LiquidGlass.interactiveSpring) {
                proxy.scrollTo("SCROLL_TO_TOP_ANCHOR", anchor: .top)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                Text(LanguageManager.shared.string(.scrollToTop))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .liquidGlassCapsule(interactive: true)
            .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(BouncyButtonStyle())
        .padding(.trailing, 20)
        .padding(.bottom, 102)
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.75).combined(with: .opacity).combined(with: .offset(y: 15)),
                removal: .scale(scale: 0.85).combined(with: .opacity).combined(with: .offset(y: 10))
            )
        )
    }

    /// Floating frosted glass refresh feedback toast
    @ViewBuilder
    private func refreshToastView(status: HomeViewModel.RefreshStatus) -> some View {
        let isSuccess: Bool = {
            switch status {
            case .success, .upToDate: return true
            case .failed: return false
            }
        }()

        let text: String = {
            switch status {
            case .success(let count):
                return LanguageManager.shared.formatRefreshSuccess(newCount: count)
            case .upToDate:
                return LanguageManager.shared.string(.refreshUpToDate)
            case .failed:
                return LanguageManager.shared.string(.refreshFailed)
            }
        }()

        let iconName = isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        let iconColor: Color = isSuccess ? .green : .orange

        Button {
            viewModel?.dismissRefreshStatus()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(iconColor)

                Text(text)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .liquidGlassCapsule(tint: isSuccess ? Color.green.opacity(0.14) : Color.orange.opacity(0.14), interactive: true)
            .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 10)
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: -12)),
                removal: .scale(scale: 0.85).combined(with: .opacity).combined(with: .offset(y: -8))
            )
        )
        .zIndex(100)
    }
}

// MARK: - Scroll Threshold Observation (iOS 18+ / Fallback)
private extension View {
    @ViewBuilder
    func onScrollThresholdCrossed(
        threshold: CGFloat = 80,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        if #available(iOS 18.0, *) {
            self.onScrollGeometryChange(for: Bool.self) { geo in
                (geo.contentOffset.y + geo.contentInsets.top) > threshold
            } action: { oldValue, newValue in
                if oldValue != newValue {
                    onChange(newValue)
                }
            }
        } else {
            self
        }
    }
}
