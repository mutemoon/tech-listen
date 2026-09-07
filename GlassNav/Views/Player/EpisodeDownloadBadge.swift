import SwiftUI

/// Reusable Liquid Glass download badge and action component for podcast episodes.
/// Tracks real-time download progress, completion, and provides one-tap download / cancel actions.
public struct EpisodeDownloadBadge: View {
    public let episode: Episode
    @Environment(\.appContainer) private var container

    @State private var downloadState: DownloadProgressState? = nil
    @State private var isDownloaded: Bool = false

    public init(episode: Episode) {
        self.episode = episode
    }

    public var body: some View {
        Group {
            if let state = downloadState {
                // Downloading progress pill
                Button {
                    container.feedbackService.triggerTap()
                    container.downloadManager.cancelDownload(for: episode.id)
                } label: {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.65)
                            .frame(width: 14, height: 14)

                        Text("\(Int(state.progress * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlassCapsule(tint: Color.blue.opacity(0.3), interactive: true)
                    .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 2)
                    .contentShape(Capsule())
                }
                .buttonStyle(BouncyGlassButtonStyle())
                .accessibilityLabel("下载中 \(Int(state.progress * 100))%，点击取消")
            } else if isDownloaded {
                // Downloaded badge
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.blue)

                    Text("已离线")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .liquidGlassCapsule(interactive: false)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 1)
                .accessibilityLabel("已下载完成")
            } else {
                // Not downloaded button
                Button {
                    container.feedbackService.triggerTap()
                    Task {
                        do {
                            try await container.downloadManager.startDownload(for: episode)
                        } catch {
                            container.feedbackService.triggerActionFailure()
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))

                        Text("下载")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlassCapsule(interactive: true)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 1)
                    .contentShape(Capsule())
                }
                .buttonStyle(BouncyGlassButtonStyle())
                .accessibilityLabel("下载单集")
            }
        }
        .task(id: episode.id) {
            syncState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadProgressUpdated)) { notification in
            guard let state = notification.object as? DownloadProgressState,
                  state.episodeId == episode.id else { return }
            self.downloadState = state
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadDidComplete)) { notification in
            guard let epId = notification.object as? String,
                  epId == episode.id else { return }
            withAnimation(DesignSystem.LiquidGlass.interactiveSpring) {
                self.isDownloaded = true
                self.downloadState = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadDidCancel)) { notification in
            guard let epId = notification.object as? String,
                  epId == episode.id else { return }
            withAnimation(DesignSystem.LiquidGlass.interactiveSpring) {
                self.downloadState = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadDidFail)) { notification in
            guard let epId = notification.object as? String,
                  epId == episode.id else { return }
            withAnimation(DesignSystem.LiquidGlass.interactiveSpring) {
                self.downloadState = nil
            }
        }
    }

    private func syncState() {
        self.isDownloaded = container.downloadManager.isDownloaded(episodeId: episode.id)
        self.downloadState = container.downloadManager.downloadState(for: episode.id)
    }
}
