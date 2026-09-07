import SwiftUI

/// Main dictation scratch-off player view aligned with the finalized prototype.
public struct PlayerHomeView: View {
    @Environment(\.appContainer) private var container

    public let customEpisode: Episode?
    public var onBackToEpisodes: (() -> Void)? = nil

    private enum SlideDirection {
        case forward
        case backward
    }

    @State private var slideDirection: SlideDirection = .forward
    @State private var revealedIndices: Set<Int> = []
    @State private var showTranscriptSheet: Bool = false
    @State private var isEyeOpen: Bool = false
    @State private var playbackSpeeds: [Float] = [0.8, 1.0, 1.2, 1.5, 2.0]
    @State private var currentSpeedIndex: Int = 1
    @State private var isScrubbingProgress: Bool = false
    @State private var scrubProgress: Double = 0.0

    public init(episode: Episode? = nil, onBackToEpisodes: (() -> Void)? = nil) {
        self.customEpisode = episode
        self.onBackToEpisodes = onBackToEpisodes
    }

    private var episode: Episode? {
        customEpisode ?? container.appState.activeEpisode
    }

    private var segments: [TranscriptSegment] {
        container.appState.currentSegments
    }

    private var currentSegmentIndex: Int {
        container.appState.currentSegmentIndex
    }

    private var currentSegment: TranscriptSegment? {
        container.appState.currentSegment
    }

    private var currentTokens: [WordToken] {
        guard let text = currentSegment?.text else { return [] }
        return WordToken.parse(from: text)
    }

    private var maskableWordCount: Int {
        currentTokens.filter(\.isMaskable).count
    }

    private var currentWords: [String] {
        currentTokens.filter(\.isMaskable).map(\.word)
    }

    public var body: some View {
        Group {
            if let ep = episode {
                playerContentView(episode: ep)
            } else {
                emptyStateView
            }
        }
        .task(id: episode?.id) {
            resetWordState()
            await loadSegments()
        }
        .onChange(of: revealedIndices) { _, newIndices in
            if maskableWordCount > 0 && newIndices.count >= maskableWordCount {
                if !isEyeOpen {
                    isEyeOpen = true
                }
            } else if isEyeOpen && newIndices.count < maskableWordCount {
                isEyeOpen = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("didFinishSegmentPlayback"))) { _ in
            container.feedbackService.triggerActionSuccess()
        }
    }

    // MARK: - Player Content View
    private func playerContentView(episode: Episode) -> some View {
        VStack(spacing: 0) {
            // Standardized Page Header: Title "精听" and "全文" button
            PageHeaderView(title: TabItem.player.title) {
                Button {
                    container.feedbackService.triggerTap()
                    showTranscriptSheet = true
                } label: {
                    Image(systemName: "doc.text")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .liquidGlassCircle(interactive: true)
                        .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 2)
                        .contentShape(Circle())
                }
                .buttonStyle(BouncyGlassButtonStyle())
                .accessibilityLabel("全文")
            }

            Spacer(minLength: 8)

            // Middle: Words Floating Directly on Screen
            if !currentTokens.isEmpty {
                WordScratchCardView(
                    tokens: currentTokens,
                    revealedIndices: $revealedIndices,
                    onScratchWord: { _ in
                        container.feedbackService.triggerTap()
                    },
                    onSwipeLeft: {
                        goToNextSegment()
                    },
                    onSwipeRight: {
                        goToPreviousSegment()
                    }
                )
                .id(currentSegmentIndex)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: slideDirection == .forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: slideDirection == .forward ? .leading : .trailing).combined(with: .opacity)
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer(minLength: 8)

            // Bottom Section
            bottomSection(episode: episode)
                .padding(.horizontal, 20)
                .padding(.bottom, 60)
        }
        .sheet(isPresented: $showTranscriptSheet) {
            TranscriptSheetView(
                segments: segments,
                currentSegmentIndex: currentSegmentIndex
            ) { selectedSegment, selectedIndex in
                container.appState.selectSegment(at: selectedIndex)
                resetWordState()
                container.appState.playCurrentSentence(using: container.audioPlayer)
            }
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            PageHeaderView(title: TabItem.player.title) {
                Color.clear.frame(width: 38, height: 38)
            }

            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)

                Text("暂无单集")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Button {
                    container.feedbackService.triggerTap()
                    withAnimation(DesignSystem.LiquidGlass.interactiveSpring) {
                        container.appState.selectedTab = .episodes
                    }
                } label: {
                    Text("浏览单集")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .liquidGlassCapsule(interactive: true)
                        .contentShape(Capsule())
                }
                .buttonStyle(BouncyGlassButtonStyle())
                .accessibilityLabel("浏览单集")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Section
    private func bottomSection(episode: Episode) -> some View {
        VStack(spacing: 14) {
            // Title & Speaker
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(episode.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text("\(currentSegmentIndex + 1) / \(max(1, segments.count))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .liquidGlassCapsule(interactive: false)
                }

                let authorText: String = {
                    if let speaker = currentSegment?.speaker, !speaker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return speaker
                    }
                    return episode.displayAuthor
                }()

                Text(authorText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Whole Episode Progress Bar
            podcastProgressBar(episode: episode)

            // Control Buttons Row: Previous, Next, Eye Toggle | Speed
            HStack {
                AdaptiveGlassContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        // Previous
                        Button {
                            goToPreviousSegment()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .liquidGlassCircle(interactive: true)
                                .shadow(color: Color.black.opacity(0.16), radius: 7, x: 0, y: 2)
                                .contentShape(Circle())
                        }
                        .buttonStyle(BouncyGlassButtonStyle())
                        .accessibilityLabel("上一句")

                        // Next
                        Button {
                            goToNextSegment()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .liquidGlassCircle(interactive: true)
                                .shadow(color: Color.black.opacity(0.16), radius: 7, x: 0, y: 2)
                                .contentShape(Circle())
                        }
                        .buttonStyle(BouncyGlassButtonStyle())
                        .accessibilityLabel("下一句")

                        // Eye Toggle
                        Button {
                            toggleEye()
                        } label: {
                            Image(systemName: isEyeOpen ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isEyeOpen ? .blue : .white)
                                .frame(width: 50, height: 50)
                                .liquidGlassCircle(tint: isEyeOpen ? Color.blue.opacity(0.25) : nil, interactive: true)
                                .shadow(color: isEyeOpen ? Color.blue.opacity(0.35) : Color.black.opacity(0.16), radius: 7, x: 0, y: 2)
                                .contentShape(Circle())
                        }
                        .buttonStyle(BouncyGlassButtonStyle())
                        .accessibilityLabel("切换遮罩")
                    }
                }

                Spacer()

                // Speed Button
                Button {
                    cyclePlaybackSpeed()
                } label: {
                    Text(String(format: "%.1fx", playbackSpeeds[currentSpeedIndex]))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .liquidGlassCircle(interactive: true)
                        .shadow(color: Color.black.opacity(0.16), radius: 7, x: 0, y: 2)
                        .contentShape(Circle())
                }
                .buttonStyle(BouncyGlassButtonStyle())
                .accessibilityLabel("播放速度")
            }
        }
    }

    // MARK: - Progress Bar
    private func podcastProgressBar(episode: Episode) -> some View {
        let totalDuration = max(1.0, container.audioPlayer.duration > 0 ? container.audioPlayer.duration : episode.duration)
        let activeTime: TimeInterval = {
            if isScrubbingProgress {
                return scrubProgress * totalDuration
            }
            if container.audioPlayer.currentTime > 0 {
                return container.audioPlayer.currentTime
            }
            if let segSeconds = currentSegment?.seconds, segSeconds > 0 {
                return segSeconds
            }
            return container.appState.restoredPlaybackPosition ?? 0
        }()
        let currentProgress = min(1.0, max(0.0, activeTime / totalDuration))

        return VStack(spacing: 5) {
            GeometryReader { geo in
                let width = geo.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.15))
                        .frame(height: 6)

                    LinearGradient(
                        colors: [.blue, .indigo, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(Capsule())
                    .frame(width: max(6, width * CGFloat(currentProgress)), height: 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isScrubbingProgress = true
                            scrubProgress = min(1.0, max(0.0, Double(val.location.x / width)))
                        }
                        .onEnded { _ in
                            let targetTime = scrubProgress * totalDuration
                            handleScrubEnded(targetTime: targetTime)
                        }
                )
            }
            .frame(height: 12)

            HStack {
                Text(formatDuration(activeTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatDuration(totalDuration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Logic & Actions
    private func loadSegments() async {
        guard let ep = episode else {
            container.appState.setSegments([])
            return
        }

        do {
            let loaded = try await container.episodeRepository.fetchTranscript(for: ep)
            container.appState.setSegments(loaded)
            resetWordState()

            // If audio player is not playing, park it at the restored/current segment position
            if let currentSeg = container.appState.currentSegment {
                let nextSeconds: Double = currentSeg.endSeconds ?? (
                    (container.appState.currentSegmentIndex + 1 < loaded.count)
                        ? loaded[container.appState.currentSegmentIndex + 1].seconds
                        : (currentSeg.seconds + 5.0)
                )
                if !container.audioPlayer.isPlaying {
                    if container.audioPlayer.currentEpisode?.id != ep.id || container.audioPlayer.currentSegment?.id != currentSeg.id {
                        container.audioPlayer.park(on: currentSeg, in: ep, endTime: nextSeconds)
                    }
                } else if container.audioPlayer.currentSegmentEndTime == nil {
                    container.audioPlayer.updateCurrentSegmentBoundary(currentSeg, endTime: nextSeconds)
                }
            }
        } catch {
            container.appState.setSegments([])
        }
    }

    private func resetWordState() {
        revealedIndices.removeAll()
        isEyeOpen = false
    }

    private func selectSegment(at index: Int) {
        guard index >= 0 && index < segments.count else { return }
        slideDirection = index > currentSegmentIndex ? .forward : .backward
        withAnimation(DesignSystem.LiquidGlass.interactiveSpring) {
            container.appState.selectSegment(at: index)
        }
        resetWordState()
        container.appState.playCurrentSentence(using: container.audioPlayer)
    }

    private func handleScrubEnded(targetTime: TimeInterval) {
        isScrubbingProgress = false
        if let idx = segments.lastIndex(where: { $0.seconds <= targetTime }) {
            selectSegment(at: idx)
        } else {
            container.audioPlayer.seek(to: targetTime)
        }
    }

    private func goToPreviousSegment() {
        guard currentSegmentIndex > 0 else { return }
        container.feedbackService.triggerTap()
        slideDirection = .backward
        withAnimation(DesignSystem.LiquidGlass.interactiveSpring) {
            container.appState.previousSegment()
        }
        resetWordState()
        container.appState.playCurrentSentence(using: container.audioPlayer)
    }

    private func goToNextSegment() {
        guard currentSegmentIndex + 1 < segments.count else { return }
        container.feedbackService.triggerTap()
        slideDirection = .forward
        withAnimation(DesignSystem.LiquidGlass.interactiveSpring) {
            container.appState.nextSegment()
        }
        resetWordState()
        container.appState.playCurrentSentence(using: container.audioPlayer)
    }

    private func toggleEye() {
        container.feedbackService.triggerTap()
        isEyeOpen.toggle()
        if isEyeOpen {
            revealedIndices = Set(0..<maskableWordCount)
        } else {
            revealedIndices.removeAll()
        }
    }

    private func cyclePlaybackSpeed() {
        container.feedbackService.triggerTap()
        currentSpeedIndex = (currentSpeedIndex + 1) % playbackSpeeds.count
        container.audioPlayer.setPlaybackRate(playbackSpeeds[currentSpeedIndex])
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
