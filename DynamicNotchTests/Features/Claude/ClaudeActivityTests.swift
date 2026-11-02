import XCTest
@testable import DynamicNotch

final class ClaudeActivityTests: XCTestCase {
    private func payload(_ json: String) throws -> ClaudeHookPayload {
        try JSONDecoder().decode(ClaudeHookPayload.self, from: Data(json.utf8))
    }

    func testPromptShowsThinkingWithProject() throws {
        let p = try payload(#"{"hook_event_name":"UserPromptSubmit","prompt":"fix the bug","cwd":"/Users/me/app"}"#)
        let activity = ClaudeActivityReducer.reduce(p) { _ in nil }
        XCTAssertEqual(activity?.phase, .working)
        XCTAssertEqual(activity?.detail, "fix the bug")
        XCTAssertEqual(activity?.project, "app")
    }

    func testNotificationShowsWaiting() throws {
        let p = try payload(#"{"hook_event_name":"Notification","message":"Claude needs permission"}"#)
        XCTAssertEqual(ClaudeActivityReducer.reduce(p) { _ in nil }?.phase, .waiting)
    }

    func testStopUsesLastReplyAndClips() throws {
        let p = try payload(#"{"hook_event_name":"Stop","transcript_path":"/x.jsonl"}"#)
        let long = String(repeating: "a", count: 500)
        let activity = ClaudeActivityReducer.reduce(p) { _ in long }
        XCTAssertEqual(activity?.phase, .done)
        XCTAssertEqual(activity?.detail.count, ClaudeActivityReducer.maxDetailLength + 1)
    }

    func testExpandsForThinkingWaitingDoneButNotTools() throws {
        func expands(_ json: String) throws -> Bool? {
            ClaudeActivityReducer.reduce(try payload(json)) { _ in "narration" }?.expands
        }
        XCTAssertEqual(try expands(#"{"hook_event_name":"UserPromptSubmit","prompt":"x"}"#), true)
        XCTAssertEqual(try expands(#"{"hook_event_name":"Notification","message":"x"}"#), true)
        XCTAssertEqual(try expands(#"{"hook_event_name":"Stop","transcript_path":"/x.jsonl"}"#), true)
        XCTAssertEqual(try expands(#"{"hook_event_name":"PreToolUse","tool_name":"Read","transcript_path":"/x.jsonl"}"#), false)
    }

    func testToolEventShowsNarrationAndShortLabel() throws {
        let p = try payload(#"{"hook_event_name":"PreToolUse","tool_name":"Read","transcript_path":"/x.jsonl"}"#)
        let activity = ClaudeActivityReducer.reduce(p) { _ in "Reading the config first" }
        XCTAssertEqual(activity?.detail, "Reading the config first")
        XCTAssertEqual(activity?.compactLabel, "Read")
    }

    func testToolSentenceDescribesWhatClaudeIsDoing() throws {
        func sentence(_ json: String) throws -> String? {
            ClaudeActivityReducer.reduce(try payload(json)) { _ in nil }?.toolDetail
        }
        XCTAssertEqual(try sentence(#"{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/a/b/File.swift"}}"#), "Reading File.swift")
        XCTAssertEqual(try sentence(#"{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/a/Other.swift"}}"#), "Editing Other.swift")
        XCTAssertEqual(try sentence(#"{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls","description":"List files"}}"#), "Running: List files")
        XCTAssertEqual(try sentence(#"{"hook_event_name":"PreToolUse","tool_name":"Grep","tool_input":{"pattern":"TODO"}}"#), "Searching for TODO")
        XCTAssertEqual(try sentence(#"{"hook_event_name":"PreToolUse","tool_name":"mcp__x__make_thing"}"#), "Using make thing")
    }

    func testSessionEndHides() throws {
        XCTAssertNil(ClaudeActivityReducer.reduce(try payload(#"{"hook_event_name":"SessionEnd"}"#)) { _ in nil })
    }

    func testTranscriptOutsideClaudeDirectoryIsNotRead() {
        XCTAssertNil(ClaudeActivityReducer.lastAssistantText(inTranscriptAt: "/etc/hosts"))
        XCTAssertNil(ClaudeActivityReducer.lastAssistantText(inTranscriptAt: "/tmp/evil.jsonl"))
    }

    func testRequestParsingRequiresHeaderAndPath() {
        let body = #"{"a":1}"#
        func request(_ line: String, header: Bool) -> Data {
            Data("\(line)\r\n\(header ? "X-Notchhaven-Client: t\r\n" : "")Content-Length: \(body.count)\r\n\r\n\(body)".utf8)
        }
        guard case .request(let parsed) = ClaudeEventServer.parse(request("POST /event HTTP/1.1", header: true)) else {
            return XCTFail("expected request")
        }
        XCTAssertEqual(String(decoding: parsed, as: UTF8.self), body)
        guard case .rejected = ClaudeEventServer.parse(request("POST /event HTTP/1.1", header: false)) else { return XCTFail() }
        guard case .rejected = ClaudeEventServer.parse(request("GET /event HTTP/1.1", header: true)) else { return XCTFail() }
    }
}

final class ClaudeToolLabelTests: XCTestCase {
    func testMcpToolNamesAreShortened() {
        XCTAssertEqual(ClaudeActivityReducer.toolLabel("mcp__server__list_files"), "list files")
        XCTAssertEqual(ClaudeActivityReducer.toolLabel("Bash"), "Bash")
    }
}

final class ClaudeLayoutTests: XCTestCase {
    private func activity(label: String = "Read", tool: String? = nil, detail: String = "") -> ClaudeActivity {
        ClaudeActivity(phase: .working, headline: "Running \(label)", detail: detail, project: "p", compactLabel: label, toolDetail: tool)
    }

    func testCompactWidthGrowsWithLabelButStaysBounded() {
        XCTAssertEqual(ClaudeLayout.compactExtraWidth(activity(label: "Read")), 112)
        XCTAssertGreaterThan(ClaudeLayout.compactExtraWidth(activity(label: "list all the files")), 220)
        XCTAssertEqual(ClaudeLayout.compactExtraWidth(activity(label: String(repeating: "x", count: 80))), 260)
    }

    func testExpandedHeightFollowsContent() {
        let short = ClaudeLayout.expandedExtraHeight(activity(tool: "Reading A.swift"), width: 600)
        let long = ClaudeLayout.expandedExtraHeight(activity(tool: "Reading A.swift", detail: String(repeating: "word ", count: 80)), width: 600)
        XCTAssertGreaterThan(long, short)
        XCTAssertLessThanOrEqual(long, 56 + 2 * 20 + 4 * 17)
    }
}
