import SwiftUI

/// Clean glass card presenting episode information, progress bar, and delete confirmation.
struct HomeEpisodeCard: View {
    @Environment(\.appContainer) private var container
    let episode: Episode
    let isDownloaded: Bool
    let downloadProgress: Double?
    let downloadState: DownloadProgressState?
    let onDownload: () -> Void
    let onCancel: (() -> Void)?
    let onDelete: () -> Void

    init(
        episode: Episode,
        isDownloaded: Bool,
        downloadProgress: Double? = nil,
        downloadState: DownloadProgressState? = nil,
        onDownload: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        onDelete: @escaping () -> Void
    ) {
        self.episode = episode
        self.isDownloaded = isDownloaded
        self.downloadProgress = downloadProgress
        self.downloadState = downloadState
        self.onDownload = onDownload
        self.onCancel = onCancel
        self.onDelete = onDelete
    }

    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack {
                Text("#\(episode.episodeNumber)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [.blue, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )

                Spacer()

                Text(episode.pubDate)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Title
            Text(episode.title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)

            // Guest
            HStack(spacing: 6) {
                Image(systemName: "person")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary.opacity(0.75))

                Text(episode.guest)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Divider()
                .opacity(0.2)

            // Bottom Action Row
            if let state = downloadState {
                VStack(alignment: .trailing, spacing: 10) {
                    downloadProgressView(state: state)
                    HStack {
                        metadataRow
                        Spacer()
                        playButton
                    }
                }
            } else if let progress = downloadProgress {
                HStack(alignment: .center) {
                    metadataRow
                    Spacer()
                    playButton
                    let percent = Int(progress * 100)
                    HStack(spacing: 8) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 80)
                            .tint(.secondary)

                        Text("\(percent)%")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(alignment: .center) {
                    metadataRow
                    Spacer()

                    HStack(spacing: 8) {
                        playButton

                        if isDownloaded {
                            deleteButton
                        } else {
                            downloadButton
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassBackground(
            shape: RoundedRectangle(
                cornerRadius: container.configurationService.cardCornerRadius,
                style: .continuous
            ),
            material: .ultraThinMaterial,
            strokeWidth: container.configurationService.glassStrokeWidth,
            shadowRadius: container.configurationService.glassShadowRadius
        )
    }

    // MARK: - Subviews

    @ViewBuilder
    private var metadataRow: some View {
        HStack(spacing: 10) {
            if episode.duration > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.75))

                    Text(LanguageManager.shared.formatDuration(episode.duration))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if episode.totalSegments > 0 {
                HStack(spacing: 2) {
                    Text("\(episode.totalSegments)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(LanguageManager.shared.string(.sentencesUnit))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func downloadProgressView(state: DownloadProgressState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Upper row: Progress Bar + Percentage + Cancel Button
            HStack(spacing: 8) {
                ProgressView(value: state.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.blue)

                Text("\(Int(state.progress * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .frame(minWidth: 32, alignment: .trailing)

                if let onCancel = onCancel {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 2)
                }
            }

            // Lower row: Download Speed, Remaining Size, Estimated Time
            HStack(spacing: 8) {
                // Rate
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                    Text(LanguageManager.shared.formatDownloadSpeed(state.bytesPerSecond))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .monospacedDigit()

                Circle()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 3, height: 3)

                // Remaining size
                Text(LanguageManager.shared.formatRemainingSize(state.remainingBytes))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Circle()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 3, height: 3)

                // ETA
                Text(LanguageManager.shared.formatEstimatedTimeRemaining(state.estimatedSecondsRemaining))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()
            }
        }
    }

    // MARK: - Playback Helpers

    private var isCurrentPlaying: Bool {
        container.audioPlayer.currentEpisode?.id == episode.id && container.audioPlayer.playbackState == .playing
    }

    private var isCurrentBuffering: Bool {
        container.audioPlayer.currentEpisode?.id == episode.id && container.audioPlayer.playbackState == .buffering
    }

    @ViewBuilder
    private var playButton: some View {
        Button(action: {
            container.feedbackService.triggerTap()
            container.audioPlayer.togglePlay(episode: episode)
        }) {
            ZStack {
                if isCurrentBuffering {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(isCurrentPlaying ? .white : .primary)
                } else if isCurrentPlaying {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 13, weight: .bold))
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .offset(x: 1)
                }
            }
            .foregroundStyle(isCurrentPlaying ? .white : .primary)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(
                        isCurrentPlaying
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.blue, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ))
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
            )
            .overlay {
                if !isCurrentPlaying {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(isCurrentPlaying ? LanguageManager.shared.string(.actionPause) : LanguageManager.shared.string(.actionPlay))
    }

    @ViewBuilder
    private var downloadButton: some View {
        Button(action: onDownload) {
            Image(systemName: "arrow.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
                }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(LanguageManager.shared.string(.actionDownload))
    }

    @ViewBuilder
    private var deleteButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
                }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(LanguageManager.shared.string(.actionDelete))
        .confirmationDialog(
            LanguageManager.shared.string(.confirmDeleteTitle),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(LanguageManager.shared.string(.actionDelete), role: .destructive) {
                onDelete()
            }
            Button(LanguageManager.shared.string(.actionCancel), role: .cancel) {}
        }
    }
}
