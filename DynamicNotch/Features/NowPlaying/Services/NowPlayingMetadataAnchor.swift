import Foundation

/// Keeps a browser video's title, artist and artwork steady.
///
/// YouTube (notably in Safari) can briefly hand the page's media info to a
/// different video, such as a hover preview, while the real video's timeline keeps
/// running. The result is the right progress bar under the wrong title.
/// A video is the same one while its length is unchanged and its position keeps
/// counting up, so descriptive metadata that changes under those conditions is ignored.
struct NowPlayingMetadataAnchor {
    private var anchor: NowPlayingSnapshot?
    private var lastElapsed: TimeInterval = 0

    static let durationTolerance: TimeInterval = 0.5
    static let seekBackTolerance: TimeInterval = 2

    mutating func resolve(_ snapshot: NowPlayingSnapshot) -> NowPlayingSnapshot {
        guard Self.isBrowser(snapshot.playbackSource), snapshot.duration > 0 else {
            anchor = nil
            return snapshot
        }
        defer { lastElapsed = snapshot.elapsedTime }

        guard let current = anchor,
              current.playbackSource == snapshot.playbackSource,
              abs(current.duration - snapshot.duration) <= Self.durationTolerance,
              snapshot.elapsedTime >= lastElapsed - Self.seekBackTolerance else {
            // New video (different length, restarted, or different source): trust what it says.
            anchor = snapshot
            return snapshot
        }

        let changed = !snapshot.title.trimmed.isEmpty && !current.title.trimmed.isEmpty
            && snapshot.title != current.title
        guard changed else {
            // Same video; accept late-arriving details such as a title or artwork.
            if current.title.trimmed.isEmpty || current.artworkData == nil { anchor = snapshot }
            return snapshot
        }

        return NowPlayingSnapshot(
            title: current.title,
            artist: current.artist,
            album: current.album,
            duration: snapshot.duration,
            elapsedTime: snapshot.elapsedTime,
            playbackRate: snapshot.playbackRate,
            artworkData: current.artworkData ?? snapshot.artworkData,
            playbackSource: snapshot.playbackSource,
            mediaType: snapshot.mediaType,
            contentItemIdentifier: current.contentItemIdentifier,
            isShuffled: snapshot.isShuffled,
            repeatMode: snapshot.repeatMode,
            volume: snapshot.volume,
            isFavorite: snapshot.isFavorite,
            supportsFavorite: snapshot.supportsFavorite,
            supportsVolumeControl: snapshot.supportsVolumeControl,
            refreshedAt: snapshot.refreshedAt
        )
    }

    static func isBrowser(_ source: NowPlayingPlaybackSource?) -> Bool {
        let ids = [source?.bundleIdentifier, source?.parentBundleIdentifier].compactMap { $0?.lowercased() }
        let markers = ["webkit", "safari", "chrome", "firefox", "edgemac", "brave", "thebrowser", "opera", "vivaldi"]
        return ids.contains { id in markers.contains { id.contains($0) } }
    }
}
