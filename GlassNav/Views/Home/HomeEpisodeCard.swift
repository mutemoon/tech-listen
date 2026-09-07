import SwiftUI

/// Clean glass card presenting episode information, progress bar, and delete confirmation.
struct HomeEpisodeCard: View {
    let episode: Episode
    let isDownloaded: Bool
    let downloadProgress: Double?
    let downloadState: DownloadProgressState?
    let onDownload: () -> Void
    let onCancel: (() -> Void)?
    let onDelete: (() -> Void)?

    init(
        episode: Episode,
        isDownloaded: Bool,
        downloadProgress: Double? = nil,
        downloadState: DownloadProgressState? = nil,
        onDownload: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.episode = episode
        self.isDownloaded = isDownloaded
        self.downloadProgress = downloadProgress
        self.downloadState = downloadState
        self.onDownload = onDownload
        self.onCancel = onCancel
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack {
                Text("#\(episode.episodeNumber)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
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

            // Info Area & Action Button
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    if !episode.displayAuthor.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "person")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary.opacity(0.75))
                                .frame(width: 14, alignment: .center)

                            Text(episode.displayAuthor)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    metadataRow

                    if !formattedAudioSize.isEmpty {
                        dataSizeRow
                    }
                }

                if downloadState == nil && downloadProgress == nil && !isDownloaded {
                    Spacer(minLength: 8)
                    downloadButton
                }
            }

            // Bottom Progress Row (only when downloading)
            if let state = downloadState {
                downloadProgressView(state: state)
                    .padding(.top, 2)
            } else if let progress = downloadProgress {
                HStack(alignment: .center) {
                    Spacer()
                    let percent = Int(progress * 100)
                    HStack(spacing: 8) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 80)
                            .tint(.blue)

                        Text("\(percent)%")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: DesignSystem.LiquidGlass.cardCornerRadius)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var metadataRow: some View {
        HStack(spacing: 8) {
            if episode.duration > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary.opacity(0.75))
                        .frame(width: 14, alignment: .center)

                    Text(LanguageManager.shared.formatDuration(episode.duration))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if episode.duration > 0 && episode.totalSegments > 0 {
                Circle()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 3, height: 3)
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
    private var dataSizeRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 13))
                .foregroundStyle(.secondary.opacity(0.75))
                .frame(width: 14, alignment: .center)

            HStack(spacing: 6) {
                Text(formattedAudioSize)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                if isDownloaded {
                    Circle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 3, height: 3)

                    Text(LanguageManager.shared.string(.statusDownloaded))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var formattedAudioSize: String {
        let bytes = episode.audioSizeBytes
        guard bytes > 0 else { return "" }

        let mb = Double(bytes) / (1024.0 * 1024.0)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else if mb >= 10 {
            return String(format: "%.0f MB", mb)
        } else {
            return String(format: "%.1f MB", mb)
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
                    .frame(width: 36, alignment: .trailing)

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
                // Rate: fixed width to prevent jitter
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                    Text(LanguageManager.shared.formatDownloadSpeed(state.bytesPerSecond))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 74, alignment: .leading)

                Circle()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 3, height: 3)

                // Remaining size: fixed width so "剩余" and subsequent text stay locked in place
                Text(LanguageManager.shared.formatRemainingSize(state.remainingBytes))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 80, alignment: .leading)

                Circle()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 3, height: 3)

                // ETA: fixed position so "预计" never shifts
                Text(LanguageManager.shared.formatEstimatedTimeRemaining(state.estimatedSecondsRemaining))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 86, alignment: .leading)

                Spacer()
            }
        }
    }


    @ViewBuilder
    private var downloadButton: some View {
        Button(action: onDownload) {
            Image(systemName: "arrow.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .liquidGlassCircle(interactive: true)
                .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(BouncyGlassButtonStyle())
        .accessibilityLabel(LanguageManager.shared.string(.actionDownload))
    }
}
