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
    @State private var viewModel: HomeViewModel?
    @State private var showBackToTop: Bool = false
    @State private var showSettings: Bool = false

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack(alignment: .top) {
                ZStack(alignment: .bottomTrailing) {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            Color.clear
                                .frame(height: 0)
                                .id("SCROLL_TO_TOP_ANCHOR")

                            headerView
                                .onAppear {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        showBackToTop = false
                                    }
                                }
                                .onDisappear {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        showBackToTop = true
                                    }
                                }

                            if let vm = viewModel {
                                ForEach(vm.filteredEpisodes, id: \.id) { episode in
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
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                    .refreshable {
                        await viewModel?.refresh()
                    }

                    // Floating Back to Top Button
                    if showBackToTop {
                        backToTopButton(proxy: scrollProxy)
                    }
                }

                // Floating Frosted Glass Refresh Feedback Toast
                if let status = viewModel?.refreshStatus {
                    refreshToastView(status: status)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToTopRequested)) { _ in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    scrollProxy.scrollTo("SCROLL_TO_TOP_ANCHOR", anchor: .top)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .preferredColorScheme(ThemeManager.shared.current.colorScheme)
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

    /// Floating frosted glass back to top button
    private func backToTopButton(proxy: ScrollViewProxy) -> some View {
        Button {
            container.feedbackService.triggerTap()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                proxy.scrollTo("SCROLL_TO_TOP_ANCHOR", anchor: .top)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                Text(LanguageManager.shared.string(.scrollToTop))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassCapsule(
                material: .ultraThinMaterial,
                strokeWidth: 1.0,
                shadowRadius: 14
            )
        }
        .buttonStyle(BouncyButtonStyle())
        .padding(.trailing, 20)
        .padding(.bottom, 24)
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.7).combined(with: .opacity).combined(with: .offset(y: 15)),
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
            HStack(spacing: 7) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(iconColor)

                Text(text)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .glassCapsule(
                material: .ultraThinMaterial,
                strokeWidth: 1.0,
                shadowRadius: 14
            )
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

    /// Brand header with top-right settings button
    private var headerView: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                Image(systemName: DesignSystem.Brand.logoIcon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.primary)

                Text(LanguageManager.shared.string(.brandName))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button {
                container.feedbackService.triggerTap()
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
                    }
            }
            .buttonStyle(BouncyButtonStyle())
            .accessibilityLabel(LanguageManager.shared.string(.tabSettings))
        }
        .padding(.vertical, 8)
    }
}
