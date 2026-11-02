//
//  AppRelauncher.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 4/5/26.
//

internal import AppKit

enum AppRelauncher {
    @MainActor
    static func restartApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
                """
                while kill -0 "$2" 2>/dev/null; do sleep 0.1; done
                open -n "$1"
                """,
            "sh",
            Bundle.main.bundlePath,
            String(ProcessInfo.processInfo.processIdentifier)
        ]
        
        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            return
        }
    }
}
