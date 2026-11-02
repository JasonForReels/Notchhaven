import SwiftUI

/// Sizes the notch from what Claude is doing, so short states stay small and
/// long text gets room. Character widths are estimates for the fonts used below.
enum ClaudeLayout {
    static func compactExtraWidth(_ activity: ClaudeActivity?) -> CGFloat {
        let label = activity?.compactLabel ?? activity?.headline ?? ""
        // Each side of the hardware notch needs room for the icon or the label.
        return max(110, min(260, 2 * (7.5 * CGFloat(label.count) + 26)))
    }

    static func expandedExtraWidth(_ activity: ClaudeActivity?) -> CGFloat {
        let text = (activity?.toolDetail ?? "") + (activity?.detail ?? "")
        return text.isEmpty ? 250 : (text.count < 60 ? 290 : 340)
    }

    static func expandedExtraHeight(_ activity: ClaudeActivity?, width: CGFloat) -> CGFloat {
        let usable = max(width - 76, 200)
        func lines(_ text: String?, charWidth: CGFloat, limit: Int) -> Int {
            guard let text, !text.isEmpty else { return 0 }
            return min(limit, Int((CGFloat(text.count) * charWidth / usable).rounded(.up)))
        }
        let sentence = lines(activity?.toolDetail, charWidth: 8.5, limit: 2)
        let narration = lines(activity?.detail, charWidth: 6.8, limit: 4)
        return 56 + CGFloat(sentence) * 20 + CGFloat(narration) * 17
    }
}

struct ClaudeNotchContent: NotchContentProtocol, DynamicIslandCustomizable {
    static let contentID = "claude.activity"

    let id = ClaudeNotchContent.contentID
    @MainActor let center: ClaudeActivityCenter
    /// What was current when this content was sent; drives the sizes below.
    let snapshot: ClaudeActivity?

    var priority: Int { NotchContentPriority.default }
    var isExpandable: Bool { true }
    var strokeColor: Color { Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.4) }

    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + ClaudeLayout.compactExtraWidth(snapshot), height: baseHeight)
    }

    func dynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + ClaudeLayout.compactExtraWidth(snapshot) - 10, height: baseHeight)
    }

    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let extra = ClaudeLayout.expandedExtraWidth(snapshot)
        return .init(width: baseWidth + extra, height: baseHeight + ClaudeLayout.expandedExtraHeight(snapshot, width: baseWidth + extra))
    }

    func expandedDynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let extra = ClaudeLayout.expandedExtraWidth(snapshot) + 10
        return .init(width: baseWidth + extra, height: baseHeight + ClaudeLayout.expandedExtraHeight(snapshot, width: baseWidth + extra) - 10)
    }

    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: 26, bottom: 40)
    }

    func expandedDynamicIslandCornerRadius(baseHeight: CGFloat) -> CGFloat {
        baseHeight * 0.5
    }

    @MainActor func compactView() -> AnyView {
        AnyView(ClaudeCompactView(center: center))
    }

    @MainActor func expandedView() -> AnyView {
        AnyView(ClaudeExpandedView(center: center))
    }
}

private enum ClaudeStyle {
    static let accent = Color(red: 0.85, green: 0.47, blue: 0.34)

    static func symbol(for phase: ClaudePhase) -> String {
        switch phase {
        case .working: "sparkle"
        case .waiting: "hand.raised.fill"
        case .done: "checkmark.circle.fill"
        }
    }

    static func color(for phase: ClaudePhase) -> Color {
        switch phase {
        case .working: accent
        case .waiting: .yellow
        case .done: .green
        }
    }

}

private struct ClaudeCompactView: View {
    @ObservedObject var center: ClaudeActivityCenter
    @Environment(\.notchScale) private var scale
    @Environment(\.isNotchlessScreen) private var isNotchlessScreen
    @State private var pulse = false

    /// The hardware notch hides the middle of the bar, so only an icon (left)
    /// and a short label (right) go here; the full text lives in the expanded view.
    var body: some View {
        let phase = center.activity?.phase ?? .working
        HStack {
            Image(systemName: ClaudeStyle.symbol(for: phase))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ClaudeStyle.color(for: phase))
                .opacity(phase == .working && pulse ? 0.45 : 1)
            Spacer()
            Text(center.activity?.compactLabel ?? center.activity?.headline ?? "")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ClaudeStyle.color(for: phase))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, isNotchlessScreen ? 10.scaled(by: scale) : 16.scaled(by: scale))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

private struct ClaudeExpandedView: View {
    @ObservedObject var center: ClaudeActivityCenter
    @Environment(\.isNotchlessScreen) private var isNotchlessScreen

    var body: some View {
        let activity = center.activity
        let phase = activity?.phase ?? .working
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: ClaudeStyle.symbol(for: phase))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ClaudeStyle.color(for: phase))
                Text(activity?.headline ?? "")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(ClaudeStyle.color(for: phase))
                    .lineLimit(1)
                Spacer()
                if let project = activity?.project, !project.isEmpty {
                    Text(project)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            if let tool = activity?.toolDetail, !tool.isEmpty {
                Text(tool)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let detail = activity?.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, isNotchlessScreen ? 0 : 24)
        .padding(.leading, isNotchlessScreen ? 25 : 40)
        .padding(.trailing, isNotchlessScreen ? 15 : 36)
    }
}
