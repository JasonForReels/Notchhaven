import XCTest
@testable import DynamicNotch

final class NowPlayingMetadataAnchorTests: XCTestCase {
    private let safari = NowPlayingPlaybackSource(
        bundleIdentifier: "com.apple.WebKit.GPU",
        parentBundleIdentifier: "com.apple.Safari",
        processIdentifier: 1
    )

    private func snapshot(
        _ title: String, artist: String = "A", duration: TimeInterval = 8005, elapsed: TimeInterval,
        source: NowPlayingPlaybackSource? = nil
    ) -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: title, artist: artist, album: "", duration: duration, elapsedTime: elapsed,
            playbackRate: 1, artworkData: nil, playbackSource: source ?? safari, refreshedAt: Date()
        )
    }

    func testForeignTitleWithSameTimelineIsIgnored() {
        var anchor = NowPlayingMetadataAnchor()
        _ = anchor.resolve(snapshot("Sidemen", artist: "MoreSidemen", elapsed: 5000))
        let result = anchor.resolve(snapshot("Steve Harvey", artist: "Jackpot", elapsed: 5003))
        XCTAssertEqual(result.title, "Sidemen")
        XCTAssertEqual(result.artist, "MoreSidemen")
        XCTAssertEqual(result.elapsedTime, 5003)
    }

    func testOriginalMetadataReturnsAfterPreview() {
        var anchor = NowPlayingMetadataAnchor()
        _ = anchor.resolve(snapshot("Sidemen", elapsed: 5000))
        _ = anchor.resolve(snapshot("Steve Harvey", elapsed: 5003))
        XCTAssertEqual(anchor.resolve(snapshot("Sidemen", elapsed: 5006)).title, "Sidemen")
    }

    func testNextVideoWithRestartedTimelineIsAccepted() {
        var anchor = NowPlayingMetadataAnchor()
        _ = anchor.resolve(snapshot("Sidemen", elapsed: 8000))
        XCTAssertEqual(anchor.resolve(snapshot("Next Video", elapsed: 1)).title, "Next Video")
    }

    func testDifferentLengthIsANewVideo() {
        var anchor = NowPlayingMetadataAnchor()
        _ = anchor.resolve(snapshot("Sidemen", elapsed: 5000))
        XCTAssertEqual(anchor.resolve(snapshot("Short clip", duration: 120, elapsed: 5003)).title, "Short clip")
    }

    func testNonBrowserSourcesAreNeverChanged() {
        let music = NowPlayingPlaybackSource(bundleIdentifier: "com.apple.Music", parentBundleIdentifier: nil, processIdentifier: 2)
        var anchor = NowPlayingMetadataAnchor()
        _ = anchor.resolve(snapshot("Song A", elapsed: 100, source: music))
        XCTAssertEqual(anchor.resolve(snapshot("Song B", elapsed: 103, source: music)).title, "Song B")
    }
}
