import Testing
import Foundation
@testable import GlassNav

@Suite("Sentence Playback State Machine Tests")
struct SentencePlaybackStateTests {

    @Test("SentencePlaybackState isPlaying correctness")
    func testIsPlaying() {
        #expect(SentencePlaybackState.idle.isPlaying == false)
        #expect(SentencePlaybackState.ready(segmentId: "seg_1", position: 10.0).isPlaying == false)
        #expect(SentencePlaybackState.buffering(segmentId: "seg_1").isPlaying == false)
        #expect(SentencePlaybackState.playing(segmentId: "seg_1", position: 12.0).isPlaying == true)
        #expect(SentencePlaybackState.paused(segmentId: "seg_1", position: 12.5).isPlaying == false)
        #expect(SentencePlaybackState.completed(segmentId: "seg_1").isPlaying == false)
    }

    @Test("SentencePlaybackState segmentId extraction")
    func testSegmentIdExtraction() {
        #expect(SentencePlaybackState.idle.segmentId == nil)
        #expect(SentencePlaybackState.ready(segmentId: "seg_1", position: 10.0).segmentId == "seg_1")
        #expect(SentencePlaybackState.buffering(segmentId: "seg_2").segmentId == "seg_2")
        #expect(SentencePlaybackState.playing(segmentId: "seg_3", position: 12.0).segmentId == "seg_3")
        #expect(SentencePlaybackState.paused(segmentId: "seg_4", position: 12.5).segmentId == "seg_4")
        #expect(SentencePlaybackState.completed(segmentId: "seg_5").segmentId == "seg_5")
    }

    @Test("AudioPlayer initialization defaults to idle")
    @MainActor
    func testPlayerInitialState() {
        let player = StandardAudioPlayer()
        #expect(player.sentenceState == .idle)
        #expect(player.playbackState == .stopped)
        #expect(player.isPlaying == false)
        #expect(player.currentTime == 0)
    }

    @Test("Park method sets state to ready and parks currentTime without playing")
    @MainActor
    func testParkMethod() {
        let player = StandardAudioPlayer()
        let ep = Episode(id: "ep_1", episodeNumber: 1, title: "Test", guest: "Guest", pubDate: "2026-09-05", audioURL: "https://example.com/audio.mp3", duration: 100)
        let seg = TranscriptSegment(id: "seg_1", speaker: "Host", timestamp: "00:10", seconds: 10.0, endSeconds: 15.0, text: "Hello world")

        player.park(on: seg, in: ep, endTime: 15.0)

        #expect(player.sentenceState == .ready(segmentId: "seg_1", position: 10.0))
        #expect(player.currentTime == 10.0)
        #expect(player.duration == 100.0)
        #expect(player.isPlaying == false)
        #expect(player.currentSegment?.id == "seg_1")
        #expect(player.currentSegmentEndTime == 15.0)
    }

    @Test("Play method sets state to buffering and updates currentTime")
    @MainActor
    func testPlayMethod() {
        let player = StandardAudioPlayer()
        let ep = Episode(id: "ep_1", episodeNumber: 1, title: "Test", guest: "Guest", pubDate: "2026-09-05", audioURL: "https://example.com/audio.mp3", duration: 100)
        let seg = TranscriptSegment(id: "seg_2", speaker: "Host", timestamp: "00:20", seconds: 20.0, endSeconds: 25.0, text: "Second segment")

        player.play(segment: seg, in: ep, endTime: 25.0)

        #expect(player.sentenceState == .buffering(segmentId: "seg_2"))
        #expect(player.currentTime == 20.0)
        #expect(player.currentSegment?.id == "seg_2")
        #expect(player.currentSegmentEndTime == 25.0)
    }

    @Test("TogglePlayPause when ready transitions to playing or buffering")
    @MainActor
    func testTogglePlayPauseWhenReady() {
        let player = StandardAudioPlayer()
        let ep = Episode(id: "ep_1", episodeNumber: 1, title: "Test", guest: "Guest", pubDate: "2026-09-05", audioURL: "https://example.com/audio.mp3", duration: 100)
        let seg = TranscriptSegment(id: "seg_3", speaker: "Host", timestamp: "00:30", seconds: 30.0, endSeconds: 35.0, text: "Third segment")

        player.park(on: seg, in: ep, endTime: 35.0)
        #expect(player.sentenceState == .ready(segmentId: "seg_3", position: 30.0))

        // When toggled while ready, it starts playback (entering buffering / playing)
        player.togglePlayPause()
        #expect(player.sentenceState == .buffering(segmentId: "seg_3") || player.sentenceState.isPlaying)
    }

    @Test("Rapid sentence switching tracks latest target accurately")
    @MainActor
    func testRapidSentenceSwitching() {
        let player = StandardAudioPlayer()
        let ep = Episode(id: "ep_1", episodeNumber: 1, title: "Test", guest: "Guest", pubDate: "2026-09-05", audioURL: "https://example.com/audio.mp3", duration: 100)
        let seg1 = TranscriptSegment(id: "seg_1", speaker: "Host", timestamp: "00:10", seconds: 10.0, endSeconds: 15.0, text: "First")
        let seg2 = TranscriptSegment(id: "seg_2", speaker: "Host", timestamp: "00:20", seconds: 20.0, endSeconds: 25.0, text: "Second")
        let seg3 = TranscriptSegment(id: "seg_3", speaker: "Host", timestamp: "00:30", seconds: 30.0, endSeconds: 35.0, text: "Third")

        // Rapidly call play on 1, 2, 3
        player.play(segment: seg1, in: ep, endTime: 15.0)
        player.play(segment: seg2, in: ep, endTime: 25.0)
        player.play(segment: seg3, in: ep, endTime: 35.0)

        // Must reliably be on seg3 with position 30.0
        #expect(player.currentSegment?.id == "seg_3")
        #expect(player.currentSegmentEndTime == 35.0)
        #expect(player.currentTime == 30.0)
        #expect(player.sentenceState == .buffering(segmentId: "seg_3"))
    }

    @Test("Pause sets state to paused with position preserved")
    @MainActor
    func testPausePreservesPosition() {
        let player = StandardAudioPlayer()
        let ep = Episode(id: "ep_1", episodeNumber: 1, title: "Test", guest: "Guest", pubDate: "2026-09-05", audioURL: "https://example.com/audio.mp3", duration: 100)
        let seg = TranscriptSegment(id: "seg_4", speaker: "Host", timestamp: "00:40", seconds: 40.0, endSeconds: 45.0, text: "Fourth")

        player.park(on: seg, in: ep, endTime: 45.0)
        player.pause()

        #expect(player.sentenceState == .paused(segmentId: "seg_4", position: 40.0))
        #expect(player.currentTime == 40.0)
        #expect(player.isPlaying == false)
    }
}
