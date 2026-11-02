import SwiftUI

struct ClaudeNotchContent: NotchContentProtocol, DynamicIslandCustomizable {
    static let contentID = "claude.activity"

    let id = ClaudeNotchContent.contentID
    @MainActor let center: ClaudeActivityCenter

    var priority: Int { NotchContentPriority.default }
    var isExpandable: Bool { true }
    var strokeColor: Color { Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.4) }

    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 210, height: baseHeight)
    }

    func dynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 200, height: baseHeight)
    }

    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 330, height: baseHeight + 120)
    }

    func expandedDynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 340, height: baseHeight + 110)
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

    /// The hardware notch hides the middle of the bar, so only an icon (left)
    /// and a short label (right) go here; the full text lives in the expanded view.
    var body: some View {
        let phase = center.activity?.phase ?? .working
        HStack {
            ClaudeOrbView(phase: phase, size: 26)
            Spacer()
            Text(center.activity?.compactLabel ?? center.activity?.headline ?? "")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ClaudeStyle.color(for: phase))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, isNotchlessScreen ? 10.scaled(by: scale) : 16.scaled(by: scale))
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
                ClaudeOrbView(phase: phase, size: 30)
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
            if let detail = activity?.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, isNotchlessScreen ? 0 : 24)
        .padding(.leading, isNotchlessScreen ? 25 : 40)
        .padding(.trailing, isNotchlessScreen ? 15 : 36)
    }
}
