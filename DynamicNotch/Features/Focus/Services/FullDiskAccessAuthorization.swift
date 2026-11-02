import Foundation

enum FullDiskAccessAuthorization {
    private static let home = FileManager.default.homeDirectoryForCurrentUser

    private static let probeURLs: [URL] = [
        home.appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json"),
        home.appendingPathComponent("Library/DoNotDisturb/DB/ModeConfigurations.json"),
        home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
    ]

    // Listing this directory is denied without Full Disk Access, and it is the
    // folder the Focus readers depend on, so it works even when no single file exists.
    private static let probeDirectory = home.appendingPathComponent("Library/DoNotDisturb/DB")

    static func hasPermission() -> Bool {
        if (try? FileManager.default.contentsOfDirectory(atPath: probeDirectory.path)) != nil {
            return true
        }
        for url in probeURLs {
            if canReadProtectedResource(at: url) {
                return true
            }
        }
        return false
    }

    private static func canReadProtectedResource(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return false
        }

        do {
            let handle = try FileHandle(forReadingFrom: url)
            try handle.close()
            return true
        } catch {
            return false
        }
    }
}
