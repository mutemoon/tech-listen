import Foundation
import AVFoundation
import MediaPlayer

/// Concrete implementation of AudioPlayerProtocol managing AVPlayer, AVAudioSession, and background lock screen controls.
@Observable
@MainActor
public final class StandardAudioPlayer: NSObject, AudioPlayerProtocol {
    public private(set) var currentEpisode: Episode? = nil
    public private(set) var playbackState: PlaybackState = .stopped
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var duration: TimeInterval = 0

    @ObservationIgnored nonisolated(unsafe) private var player: AVPlayer?
    @ObservationIgnored nonisolated(unsafe) private var timeObserverToken: Any?
    @ObservationIgnored nonisolated(unsafe) private var statusObserver: NSKeyValueObservation?
    @ObservationIgnored nonisolated(unsafe) private var timeControlStatusObserver: NSKeyValueObservation?
    @ObservationIgnored nonisolated(unsafe) private var endObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var interruptionObserver: NSObjectProtocol?

    public override init() {
        super.init()
        configureAudioSession()
        setupRemoteCommandCenter()
        setupInterruptionObserver()
    }

    deinit {
        // Clean up observers safely
        if let token = timeObserverToken, let p = player {
            p.removeTimeObserver(token)
        }
        statusObserver?.invalidate()
        timeControlStatusObserver?.invalidate()
        if let endObs = endObserver {
            NotificationCenter.default.removeObserver(endObs)
        }
        if let intrObs = interruptionObserver {
            NotificationCenter.default.removeObserver(intrObs)
        }
    }

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
                    self.resume()
                }
            }
        }
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.resume()
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
                if self.playbackState == .playing {
                    self.pause()
                } else {
                    self.resume()
                }
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

    public func play(episode: Episode) {
        if currentEpisode?.id == episode.id, player != nil {
            resume()
            return
        }

        stop()

        guard let targetURL = resolveAudioURL(for: episode) else {
            playbackState = .stopped
            return
        }

        currentEpisode = episode
        duration = episode.duration
        currentTime = 0
        playbackState = .buffering

        configureAudioSession()

        let item = AVPlayerItem(url: targetURL)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        self.player = newPlayer

        // Observe player buffering / playback state
        timeControlStatusObserver = newPlayer.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] p, _ in
            Task { @MainActor in
                guard let self = self else { return }
                switch p.timeControlStatus {
                case .playing:
                    self.playbackState = .playing
                case .paused:
                    if self.playbackState != .stopped {
                        self.playbackState = .paused
                    }
                case .waitingToPlayAtSpecifiedRate:
                    self.playbackState = .buffering
                @unknown default:
                    break
                }
                self.updateNowPlayingInfo()
            }
        }

        // Observe periodic time updates
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentTime = time.seconds
                if let currentItem = self.player?.currentItem, currentItem.duration.isNumeric {
                    self.duration = currentItem.duration.seconds
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
                self?.stop()
            }
        }

        newPlayer.play()
        updateNowPlayingInfo()
    }

    public func togglePlay(episode: Episode) {
        if currentEpisode?.id == episode.id {
            if playbackState == .playing {
                pause()
            } else {
                resume()
            }
        } else {
            play(episode: episode)
        }
    }

    public func pause() {
        guard let p = player else { return }
        p.pause()
        playbackState = .paused
        updateNowPlayingInfo()
    }

    public func resume() {
        guard let p = player else {
            if let ep = currentEpisode {
                play(episode: ep)
            }
            return
        }
        configureAudioSession()
        p.play()
        playbackState = .playing
        updateNowPlayingInfo()
    }

    public func stop() {
        if let token = timeObserverToken, let p = player {
            p.removeTimeObserver(token)
            timeObserverToken = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        timeControlStatusObserver?.invalidate()
        timeControlStatusObserver = nil
        if let endObs = endObserver {
            NotificationCenter.default.removeObserver(endObs)
            endObserver = nil
        }

        player?.pause()
        player = nil
        currentEpisode = nil
        playbackState = .stopped
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    public func seek(to time: TimeInterval) {
        guard let p = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        p.seek(to: cmTime)
        currentTime = time
        updateNowPlayingInfo()
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
        info[MPNowPlayingInfoPropertyPlaybackRate] = playbackState == .playing ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
