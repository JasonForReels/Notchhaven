import Combine
import Foundation

enum ClaudePhase: Equatable {
    case working
    case waiting
    case done
}

struct ClaudeActivity: Equatable {
    var phase: ClaudePhase
    var headline: String
    var detail: String
    var project: String
    /// Short text for the compact bar, where room beside the hardware notch is tight.
    var compactLabel: String? = nil
    /// Whether the notch should open to its expanded view for this state.
    var expands: Bool = false
    /// Plain-language sentence for what Claude is doing right now.
    var toolDetail: String? = nil
}

/// Hook payload as sent by Claude Code (`hook_event_name` plus event fields).
struct ClaudeHookPayload: Decodable {
    let hook_event_name: String?
    let session_id: String?
    let cwd: String?
    let tool_name: String?
    let message: String?
    let prompt: String?
    let transcript_path: String?
    let tool_input: ToolInput?

    struct ToolInput: Decodable {
        let file_path: String?
        let path: String?
        let command: String?
        let description: String?
        let pattern: String?
        let query: String?
        let url: String?
    }
}

enum ClaudeActivityReducer {
    static let maxDetailLength = 240

    /// Maps a hook payload to the activity to show, or nil to hide the notch.
    static func reduce(_ payload: ClaudeHookPayload, lastReply: (String) -> String?) -> ClaudeActivity? {
        let project = payload.cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""

        switch payload.hook_event_name {
        case "UserPromptSubmit":
            return .init(phase: .working, headline: "Thinking", detail: "", project: project, expands: true, toolDetail: payload.prompt.flatMap { $0.isEmpty ? nil : "Working on: \(clip($0))" })
        case "PreToolUse":
            let narration = payload.transcript_path.flatMap(lastReply) ?? ""
            return .init(
                phase: .working,
                headline: "Working",
                detail: clip(narration),
                project: project,
                compactLabel: payload.tool_name.map(compactVerb),
                toolDetail: toolSentence(name: payload.tool_name, input: payload.tool_input)
            )
        case "Notification":
            return .init(phase: .waiting, headline: "Needs you", detail: clip(payload.message ?? ""), project: project, expands: true)
        case "Stop":
            let reply = payload.transcript_path.flatMap(lastReply) ?? ""
            return .init(phase: .done, headline: "Done", detail: clip(reply), project: project, expands: true)
        case "SessionEnd":
            return nil
        default:
            return nil
        }
    }

    /// A plain sentence for what a tool call is about to do, e.g. "Reading File.swift".
    static func toolSentence(name: String?, input: ClaudeHookPayload.ToolInput?) -> String? {
        guard let name else { return nil }
        func file(_ i: ClaudeHookPayload.ToolInput?) -> String? {
            (i?.file_path ?? i?.path).map { URL(fileURLWithPath: $0).lastPathComponent }
        }
        switch name {
        case "Read":
            return file(input).map { "Reading \($0)" } ?? "Reading a file"
        case "Edit", "MultiEdit", "NotebookEdit":
            return file(input).map { "Editing \($0)" } ?? "Editing a file"
        case "Write":
            return file(input).map { "Writing \($0)" } ?? "Writing a file"
        case "Bash":
            if let description = input?.description, !description.isEmpty { return clip(description) }
            return humanizeCommand(input?.command)
        case "Grep", "Glob":
            return (input?.pattern).map { "Searching for \(clip($0))" } ?? "Searching the project"
        case "WebFetch":
            return (input?.url).map { "Fetching \(clip($0))" } ?? "Fetching a web page"
        case "WebSearch":
            return (input?.query).map { "Searching the web for \(clip($0))" } ?? "Searching the web"
        case "Task", "Agent":
            return input?.description.map { "Delegating: \(clip($0))" } ?? "Delegating to a subagent"
        default:
            return "Using \(toolLabel(name))"
        }
    }

    /// Plain words for a shell command, so the notch never shows the raw command line.
    static func humanizeCommand(_ command: String?) -> String {
        let text = (command ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "Running a command" }
        let rules: [(String, String)] = [
            ("xcodebuild test", "Running the tests"), ("xcodebuild", "Building the app"),
            ("swift test", "Running the tests"), ("swift build", "Building the project"),
            ("npm test", "Running the tests"), ("npm run build", "Building the project"),
            ("npm install", "Installing packages"), ("npm i ", "Installing packages"),
            ("git commit", "Committing changes"), ("git push", "Pushing changes to GitHub"),
            ("git pull", "Pulling the latest changes"), ("git merge", "Merging a branch"),
            ("git checkout", "Switching branches"), ("git switch", "Switching branches"),
            ("git status", "Checking what changed"), ("git diff", "Checking what changed"),
            ("git log", "Reading the commit history"), ("git add", "Staging changes"),
            ("gh pr", "Working with a pull request"), ("gh repo", "Working with the GitHub repo"),
            ("curl ", "Making a web request"), ("pkill", "Stopping a process"), ("killall", "Stopping a process"),
            ("open ", "Opening something"), ("codesign", "Signing the app"), ("ditto", "Copying files"),
            ("cp ", "Copying files"), ("mv ", "Moving files"), ("rm ", "Deleting files"),
            ("mkdir", "Creating a folder"), ("python", "Running a script"), ("sed ", "Editing text in files"),
            ("grep", "Searching files"), ("find ", "Searching files"), ("ls", "Listing files"),
            ("cat ", "Reading a file"), ("head ", "Reading a file"), ("tail ", "Reading a file"),
            ("defaults", "Changing a setting"), ("sleep", "Waiting a moment"),
        ]
        for (needle, phrase) in rules where text.contains(needle) { return phrase }
        return "Running a command"
    }

    /// One short verb for the compact bar.
    static func compactVerb(_ name: String) -> String {
        switch name {
        case "Read": "Reading"
        case "Edit", "MultiEdit", "NotebookEdit": "Editing"
        case "Write": "Writing"
        case "Bash": "Running"
        case "Grep", "Glob": "Searching"
        case "WebFetch", "WebSearch": "Browsing"
        case "Task", "Agent": "Delegating"
        default: toolLabel(name)
        }
    }

    /// `mcp__server__do_thing` -> `do thing`, so long MCP names stay readable.
    static func toolLabel(_ name: String) -> String {
        guard name.hasPrefix("mcp__"), let last = name.components(separatedBy: "__").last else { return name }
        return last.replacingOccurrences(of: "_", with: " ")
    }

    static func clip(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return flat.count > maxDetailLength ? String(flat.prefix(maxDetailLength)) + "…" : flat
    }

    /// Reads the last assistant text from a Claude Code transcript (JSONL).
    /// Only files named `*.jsonl` under `~/.claude/` are read.
    static func lastAssistantText(inTranscriptAt path: String) -> String? {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let allowedRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true).standardizedFileURL.path + "/"
        guard url.pathExtension == "jsonl", url.path.hasPrefix(allowedRoot),
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > 262_144 ? size - 262_144 : 0)
        let tail = String(decoding: handle.readDataToEndOfFile(), as: UTF8.self)

        for line in tail.split(separator: "\n").reversed() {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  object["type"] as? String == "assistant",
                  let message = object["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else { continue }

            let text = content.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined(separator: " ")
            if !text.isEmpty { return text }
        }
        return nil
    }
}

@MainActor
final class ClaudeActivityCenter: ObservableObject {
    static let shared = ClaudeActivityCenter()
    static let enabledKey = "settings.claude.activity.enabled"
    static let doneLingerSeconds: TimeInterval = 8

    @Published private(set) var activity: ClaudeActivity?

    private var server: ClaudeEventServer?
    private weak var notchViewModel: NotchViewModel?
    private var hideTask: Task<Void, Never>?
    private var expandTask: Task<Void, Never>?
    private var isExpandedByClaude = false
    private var transcriptPath: String?
    private var pollTask: Task<Void, Never>?
    private var defaultsObserver: AnyCancellable?

    func start(notchViewModel: NotchViewModel) {
        self.notchViewModel = notchViewModel
        defaultsObserver = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.syncServer() } }
        syncServer()
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    private func syncServer() {
        if isEnabled, server == nil {
            let server = ClaudeEventServer { [weak self] data in
                Task { @MainActor in self?.ingest(data) }
            }
            server.start()
            self.server = server
        } else if !isEnabled, server != nil {
            server?.stop()
            server = nil
            apply(nil)
        }
    }

    func ingest(_ data: Data) {
        guard isEnabled, let payload = try? JSONDecoder().decode(ClaudeHookPayload.self, from: data) else { return }
        let next = ClaudeActivityReducer.reduce(payload, lastReply: ClaudeActivityReducer.lastAssistantText(inTranscriptAt:))
        transcriptPath = payload.transcript_path ?? transcriptPath
        apply(next)
        updatePolling(for: next)

        hideTask?.cancel()
        if next?.phase == .done {
            hideTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.doneLingerSeconds))
                guard !Task.isCancelled else { return }
                self?.apply(nil)
            }
        }
    }

    /// While Claude works, keep the shown narration in step with the transcript
    /// so it reads like live thinking between hook events.
    private func updatePolling(for next: ClaudeActivity?) {
        pollTask?.cancel()
        guard next?.phase == .working, let path = transcriptPath else { return }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled, let self,
                      var current = self.activity, current.phase == .working,
                      let text = ClaudeActivityReducer.lastAssistantText(inTranscriptAt: path) else { continue }
                let clipped = ClaudeActivityReducer.clip(text)
                if clipped != current.detail {
                    current.detail = clipped
                    self.activity = current
                    self.publish(current)
                }
            }
        }
    }

    /// Re-sends the live activity; the notch updates in place and animates to the new size.
    private func publish(_ activity: ClaudeActivity) {
        notchViewModel?.send(.showLiveActivity(ClaudeNotchContent(center: self, snapshot: activity)))
    }

    private func apply(_ next: ClaudeActivity?) {
        let wasShowing = activity != nil
        activity = next
        expandTask?.cancel()

        guard let next else {
            isExpandedByClaude = false
            if wasShowing { notchViewModel?.send(.hideLiveActivity(id: ClaudeNotchContent.contentID)) }
            return
        }

        publish(next)

        if next.expands {
            // Give a freshly shown activity a moment to appear before expanding it.
            expandTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(wasShowing ? 50 : 450))
                guard !Task.isCancelled, let self else { return }
                self.notchViewModel?.expandActiveLiveActivity()
                self.isExpandedByClaude = true
            }
        } else if isExpandedByClaude {
            isExpandedByClaude = false
            notchViewModel?.handleOutsideClick()
        }
    }
}
