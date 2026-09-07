import Foundation
import AVFoundation
import MediaPlayer

/// Concrete implementation of AudioPlayerProtocol managing AVPlayer, AVAudioSession, and background lock screen controls.
@Observable
@MainActor
public final class StandardAudioPlayer: NSObject, AudioPlayerProtocol {
    public private(set) var currentEpisode: Episode? = nil
    public private(set) var playbackState: PlaybackState = .stopped
    public private(set) var sentenceState: SentencePlaybackState = .idle
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var duration: TimeInterval = 0
    public private(set) var currentSegment: TranscriptSegment? = nil
    public private(set) var currentSegmentEndTime: Double? = nil
    public private(set) var playbackRate: Float = 1.0

    public var isPlaying: Bool {
        sentenceState.isPlaying || playbackState == .playing
    }

    @ObservationIgnored nonisolated(unsafe) private var player: AVPlayer?
    @ObservationIgnored nonisolated(unsafe) private var timeObserverToken: Any?
    @ObservationIgnored nonisolated(unsafe) private var boundaryObserverToken: Any?
    @ObservationIgnored nonisolated(unsafe) private var currentSessionToken: Int = 0
    @ObservationIgnored nonisolated(unsafe) private var timeControlStatusObserver: NSKeyValueObservation?
    @ObservationIgnored nonisolated(unsafe) private var itemStatusObserver: NSKeyValueObservation?
    @ObservationIgnored nonisolated(unsafe) private var endObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var pendingSeekTime: Double?
    @ObservationIgnored nonisolated(unsafe) private var shouldAutoPlayWhenReady: Bool = false
    @ObservationIgnored nonisolated(unsafe) private var isSeeking: Bool = false

    public override init() {
        super.init()
        configureAudioSession()
        setupRemoteCommandCenter()
        setupInterruptionObserver()
    }

    deinit {
        if let token = timeObserverToken, let p = player {
            p.removeTimeObserver(token)
        }
        if let bToken = boundaryObserverToken, let p = player {
            p.removeTimeObserver(bToken)
        }
        timeControlStatusObserver?.invalidate()
        itemStatusObserver?.invalidate()
        if let endObs = endObserver {
            NotificationCenter.default.removeObserver(endObs)
        }
        if let intrObs = interruptionObserver {
            NotificationCenter.default.removeObserver(intrObs)
        }
    }

    // MARK: - Audio Session & Observers Setup

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            print("[StandardAudioPlayer] Failed to activate AVAudioSession: \(error)")
        }
    }

    private func setupInterruptionObserver() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            let shouldResume: Bool
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            } else {
                shouldResume = false
            }

            Task { @MainActor in
                guard let self = self else { return }
                if type == .began {
                    self.pause()
                } else if type == .ended && shouldResume {
                    self.togglePlayPause()
                }
            }
        }
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                if !self.isPlaying {
                    self.togglePlayPause()
                }
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.pause()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.togglePlayPause()
            }
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.seek(to: min(self.duration, self.currentTime + 15))
            }
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.seek(to: max(0, self.currentTime - 15))
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self.seek(to: positionEvent.positionTime)
            }
            return .success
        }
    }

    private func resolveAudioURL(for episode: Episode) -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let localFile = docs.appendingPathComponent("downloads", isDirectory: true).appendingPathComponent("\(episode.id).mp3")
        if FileManager.default.fileExists(atPath: localFile.path) {
            return localFile
        }
        if let urlStr = episode.audioURL, let remote = URL(string: urlStr) {
            return remote
        }
        return nil
    }

    // MARK: - Boundary Observer & Lifecycle Management

    private func clearBoundaryObserver() {
        if let token = boundaryObserverToken, let p = player {
            p.removeTimeObserver(token)
        }
        boundaryObserverToken = nil
    }

    private func setupBoundaryObserver(for endTime: Double, sessionToken: Int, segmentId: String) {
        clearBoundaryObserver()
        guard let p = player else { return }
        let targetCM = CMTime(seconds: endTime, preferredTimescale: 600)
        boundaryObserverToken = p.addBoundaryTimeObserver(forTimes: [NSValue(time: targetCM)], queue: .main) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                guard self.currentSessionToken == sessionToken else { return }
                self.handleBoundaryReached(segmentId: segmentId, endTime: endTime)
            }
        }
    }

    private func handleBoundaryReached(segmentId: String, endTime: Double) {
        guard isPlaying else { return }
        clearBoundaryObserver()
        player?.pause()
        playbackState = .paused
        sentenceState = .completed(segmentId: segmentId)
        currentTime = endTime
        updateNowPlayingInfo()
        NotificationCenter.default.post(name: Notification.Name("didFinishSegmentPlayback"), object: nil)
    }

    private func setupPlayer(
        for episode: Episode,
        startAt seconds: Double,
        segment: TranscriptSegment?,
        endTime: Double?,
        autoPlay: Bool,
        sessionToken: Int
    ) {
        clearBoundaryObserver()
        if let token = timeObserverToken, let p = player {
            p.removeTimeObserver(token)
            timeObserverToken = nil
        }
        timeControlStatusObserver?.invalidate()
        timeControlStatusObserver = nil
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        if let endObs = endObserver {
            NotificationCenter.default.removeObserver(endObs)
            endObserver = nil
        }

        guard let targetURL = resolveAudioURL(for: episode) else {
            playbackState = .stopped
            sentenceState = .idle
            return
        }

        pendingSeekTime = seconds
        shouldAutoPlayWhenReady = autoPlay

        configureAudioSession()

        let item = AVPlayerItem(url: targetURL)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        self.player = newPlayer

        // Observe player item readiness to guarantee initial seek never drops
        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] itm, _ in
            Task { @MainActor in
                guard let self = self else { return }
                guard self.currentSessionToken == sessionToken else { return }

                if itm.status == .readyToPlay {
                    if let pending = self.pendingSeekTime {
                        self.pendingSeekTime = nil
                        self.seek(to: pending) { [weak self] finished in
                            guard let self = self, self.currentSessionToken == sessionToken else { return }
                            if self.shouldAutoPlayWhenReady {
                                self.shouldAutoPlayWhenReady = false
                                if let end = endTime, let seg = segment {
                                    self.setupBoundaryObserver(for: end, sessionToken: sessionToken, segmentId: seg.id)
                                }
                                self.player?.play()
                                self.player?.rate = self.playbackRate
                                self.playbackState = .playing
                                if let seg = segment {
                                    self.sentenceState = .playing(segmentId: seg.id, position: pending)
                                }
                            } else {
                                self.playbackState = .paused
                                if let seg = segment {
                                    self.sentenceState = .ready(segmentId: seg.id, position: pending)
                                }
                            }
                            self.updateNowPlayingInfo()
                        }
                    }
                } else if itm.status == .failed {
                    self.shouldAutoPlayWhenReady = false
                    self.playbackState = .stopped
                    self.sentenceState = .idle
                }
            }
        }

        // Observe player buffering / playback state on changes
        timeControlStatusObserver = newPlayer.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            Task { @MainActor in
                guard let self = self else { return }
                guard self.currentSessionToken == sessionToken else { return }
                switch p.timeControlStatus {
                case .playing:
                    self.playbackState = .playing
                case .paused:
                    if self.playbackState != .stopped && !self.shouldAutoPlayWhenReady {
                        self.playbackState = .paused
                    }
                case .waitingToPlayAtSpecifiedRate:
                    if self.sentenceState.isPlaying {
                        self.playbackState = .buffering
                    }
                @unknown default:
                    break
                }
                self.updateNowPlayingInfo()
            }
        }

        // Periodic time observer for continuous progress display
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                guard self.currentSessionToken == sessionToken else { return }
                self.currentTime = time.seconds
                if let currentItem = self.player?.currentItem, currentItem.duration.isNumeric {
                    self.duration = currentItem.duration.seconds
                }

                // Safety fallback for boundary completion: only when actively playing in current session
                if self.sentenceState.isPlaying,
                   let endTime = self.currentSegmentEndTime,
                   let segId = self.currentSegment?.id,
                   self.currentTime >= endTime {
                    self.handleBoundaryReached(segmentId: segId, endTime: endTime)
                }
                self.updateNowPlayingInfo()
            }
        }

        // Observe end of item
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.currentSessionToken == sessionToken else { return }
                if let segId = self.currentSegment?.id {
                    self.handleBoundaryReached(segmentId: segId, endTime: self.duration)
                } else {
                    self.pause()
                }
            }
        }
    }

    // MARK: - Sentence-Oriented Lifecycle Methods

    public func park(on segment: TranscriptSegment, in episode: Episode, endTime: Double) {
        currentSessionToken += 1
        let activeToken = currentSessionToken
        clearBoundaryObserver()

        let isDifferentEpisode = currentEpisode?.id != episode.id || player == nil
        self.currentEpisode = episode
        self.currentSegment = segment
        self.currentSegmentEndTime = endTime
        self.duration = episode.duration
        self.currentTime = segment.seconds
        self.playbackState = .paused
        self.sentenceState = .ready(segmentId: segment.id, position: segment.seconds)

        if isDifferentEpisode {
            setupPlayer(for: episode, startAt: segment.seconds, segment: segment, endTime: endTime, autoPlay: false, sessionToken: activeToken)
        } else {
            player?.pause()
            seek(to: segment.seconds) { [weak self] finished in
                guard let self = self, self.currentSessionToken == activeToken else { return }
                self.currentTime = segment.seconds
                self.sentenceState = .ready(segmentId: segment.id, position: segment.seconds)
                self.updateNowPlayingInfo()
            }
        }
        updateNowPlayingInfo()
    }

    public func play(segment: TranscriptSegment, in episode: Episode, endTime: Double) {
        currentSessionToken += 1
        let activeToken = currentSessionToken
        clearBoundaryObserver()

        let isDifferentEpisode = currentEpisode?.id != episode.id || player == nil
        self.currentEpisode = episode
        self.currentSegment = segment
        self.currentSegmentEndTime = endTime
        self.duration = episode.duration
        self.currentTime = segment.seconds
        self.playbackState = .buffering
        self.sentenceState = .buffering(segmentId: segment.id)

        if isDifferentEpisode {
            setupPlayer(for: episode, startAt: segment.seconds, segment: segment, endTime: endTime, autoPlay: true, sessionToken: activeToken)
        } else {
            configureAudioSession()
            seek(to: segment.seconds) { [weak self] finished in
                guard let self = self, self.currentSessionToken == activeToken else { return }
                self.setupBoundaryObserver(for: endTime, sessionToken: activeToken, segmentId: segment.id)
                self.player?.play()
                self.player?.rate = self.playbackRate
                self.playbackState = .playing
                self.sentenceState = .playing(segmentId: segment.id, position: segment.seconds)
                self.updateNowPlayingInfo()
            }
        }
        updateNowPlayingInfo()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
            return
        }

        guard let episode = currentEpisode, let segment = currentSegment, let endTime = currentSegmentEndTime else {
            return
        }

        switch sentenceState {
        case .completed:
            replayCurrentSentence()

        case .ready:
            play(segment: segment, in: episode, endTime: endTime)

        case .paused:
            resumePlayingFromCurrentPosition(segment: segment, episode: episode, endTime: endTime)

        case .idle, .buffering:
            play(segment: segment, in: episode, endTime: endTime)

        case .playing:
            pause()
        }
    }

    private func resumePlayingFromCurrentPosition(segment: TranscriptSegment, episode: Episode, endTime: Double) {
        currentSessionToken += 1
        let activeToken = currentSessionToken

        if currentTime >= endTime - 0.05 {
            play(segment: segment, in: episode, endTime: endTime)
            return
        }

        configureAudioSession()
        setupBoundaryObserver(for: endTime, sessionToken: activeToken, segmentId: segment.id)
        player?.play()
        player?.rate = playbackRate
        playbackState = .playing
        sentenceState = .playing(segmentId: segment.id, position: currentTime)
        updateNowPlayingInfo()
    }

    public func replayCurrentSentence() {
        guard let episode = currentEpisode, let segment = currentSegment, let endTime = currentSegmentEndTime else {
            return
        }
        play(segment: segment, in: episode, endTime: endTime)
    }

    public func pause() {
        shouldAutoPlayWhenReady = false
        clearBoundaryObserver()
        player?.pause()
        playbackState = .paused
        if let seg = currentSegment {
            sentenceState = .paused(segmentId: seg.id, position: currentTime)
        } else {
            sentenceState = .idle
        }
        updateNowPlayingInfo()
    }

    public func stop() {
        currentSessionToken += 1
        shouldAutoPlayWhenReady = false
        isSeeking = false
        clearBoundaryObserver()
        if let token = timeObserverToken, let p = player {
            p.removeTimeObserver(token)
            timeObserverToken = nil
        }
        timeControlStatusObserver?.invalidate()
        timeControlStatusObserver = nil
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        if let endObs = endObserver {
            NotificationCenter.default.removeObserver(endObs)
            endObserver = nil
        }

        player?.pause()
        player = nil
        currentEpisode = nil
        currentSegment = nil
        currentSegmentEndTime = nil
        pendingSeekTime = nil
        playbackState = .stopped
        sentenceState = .idle
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    public func seek(to time: TimeInterval, completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        guard let p = player else {
            currentTime = time
            completion?(false)
            return
        }
        isSeeking = true
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        p.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentTime = time
                self.isSeeking = false
                self.updateNowPlayingInfo()
                completion?(finished)
            }
        }
        currentTime = time
        updateNowPlayingInfo()
    }

    public func setPlaybackRate(_ rate: Float) {
        self.playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
        updateNowPlayingInfo()
    }

    public func updateCurrentSegmentBoundary(_ segment: TranscriptSegment, endTime: Double) {
        self.currentSegment = segment
        self.currentSegmentEndTime = endTime
        if sentenceState.isPlaying {
            setupBoundaryObserver(for: endTime, sessionToken: currentSessionToken, segmentId: segment.id)
        }
    }

    private func updateNowPlayingInfo() {
        guard let episode = currentEpisode else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = episode.title
        info[MPMediaItemPropertyArtist] = episode.guest.isEmpty ? "Listen Tech" : episode.guest
        info[MPMediaItemPropertyPlaybackDuration] = duration > 0 ? duration : episode.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackRate) : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
