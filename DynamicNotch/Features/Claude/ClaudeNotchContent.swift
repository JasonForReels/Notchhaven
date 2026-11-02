import SwiftUI

struct ClaudeNotchContent: NotchContentProtocol, DynamicIslandCustomizable {
    static let contentID = "claude.activity"

    let id = ClaudeNotchContent.contentID
    @MainActor let center: ClaudeActivityCenter

    var priority: Int { NotchContentPriority.default }
    var isExpandable: Bool { true }
    var strokeColor: Color { Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.4) }

    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 110, height: baseHeight)
    }

    func dynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 100, height: baseHeight)
    }

    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 170, height: baseHeight + 70)
    }

    func expandedDynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 200, height: baseHeight + 60)
    }

    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: 24, bottom: 36)
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

    static func symbol(for phase: ClaudePhase) -> String {
        switch phase {
        case .working: "sparkle"
        case .waiting: "hand.raised.fill"
        case .done: "checkmark.circle.fill"
        }
    }
}

private struct ClaudeCompactView: View {
    @ObservedObject var center: ClaudeActivityCenter
    @Environment(\.notchScale) private var scale
    @State private var pulse = false

    var body: some View {
        let phase = center.activity?.phase ?? .working
        HStack {
            Image(systemName: ClaudeStyle.symbol(for: phase))
                .foregroundStyle(ClaudeStyle.color(for: phase))
                .opacity(phase == .working && pulse ? 0.45 : 1)
            Spacer()
            Text(center.activity?.headline ?? "")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ClaudeStyle.color(for: phase))
                .lineLimit(1)
        }
        .padding(.horizontal, 14.scaled(by: scale))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

private struct ClaudeExpandedView: View {
    @ObservedObject var center: ClaudeActivityCenter

    var body: some View {
        let activity = center.activity
        let phase = activity?.phase ?? .working
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: ClaudeStyle.symbol(for: phase))
                    .foregroundStyle(ClaudeStyle.color(for: phase))
                Text("Claude · \(activity?.headline ?? "")")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                if let project = activity?.project, !project.isEmpty {
                    Text(project)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            if let detail = activity?.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 20)
        .foregroundStyle(.white)
    }
}
