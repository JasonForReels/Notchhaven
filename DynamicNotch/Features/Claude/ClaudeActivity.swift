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
}

enum ClaudeActivityReducer {
    static let maxDetailLength = 240

    /// Maps a hook payload to the activity to show, or nil to hide the notch.
    static func reduce(_ payload: ClaudeHookPayload, lastReply: (String) -> String?) -> ClaudeActivity? {
        let project = payload.cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""

        switch payload.hook_event_name {
        case "UserPromptSubmit":
            return .init(phase: .working, headline: "Thinking", detail: clip(payload.prompt ?? ""), project: project, expands: true)
        case "PreToolUse":
            let narration = payload.transcript_path.flatMap(lastReply) ?? ""
            return .init(
                phase: .working,
                headline: payload.tool_name.map { "Running \(toolLabel($0))" } ?? "Working",
                detail: clip(narration),
                project: project,
                compactLabel: payload.tool_name.map(toolLabel)
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
        apply(next)

        hideTask?.cancel()
        if next?.phase == .done {
            hideTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.doneLingerSeconds))
                guard !Task.isCancelled else { return }
                self?.apply(nil)
            }
        }
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

        if !wasShowing {
            notchViewModel?.send(.showLiveActivity(ClaudeNotchContent(center: self)))
        }

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
