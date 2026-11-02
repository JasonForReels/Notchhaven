import SwiftUI
internal import AppKit

enum HomeWindowLayout {
    static let width: CGFloat = 720
    static let height: CGFloat = 580
}

/// The app's front door: what the notch is doing right now, the Claude toggle,
/// and shortcuts into each settings section.
struct HomeView: View {
    @ObservedObject private var claude = ClaudeActivityCenter.shared
    @ObservedObject private var updater = SparkleUpdater.shared
    @AppStorage(ClaudeActivityCenter.enabledKey) private var isClaudeEnabled = false
    @AppStorage(GeneralSettingsStorage.Keys.appLanguage) private var appLanguageRaw: String = DynamicNotchLanguage.system.rawValue

    private var locale: Locale { DynamicNotchLanguage.resolved(appLanguageRaw).locale }

    private let shortcuts: [SettingsRootViewModel.Section] = [
        .general, .nowPlaying, .hud, .battery, .downloads, .drop,
        .calendar, .network, .focus, .screenRecording, .lockScreen, .permissions
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                notchPreview
                claudeCard
                shortcutGrid
                footer
            }
            .padding(28)
        }
        .frame(width: HomeWindowLayout.width, height: HomeWindowLayout.height)
        .background(background)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text("Notchhaven")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(locale.dn("home.tagline", fallback: "Your notch, alive."))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(verbatim: AppVersionText.appVersionText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
    }

    // MARK: Notch preview

    private var notchPreview: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.2, green: 0.12, blue: 0.45), Color(red: 0.45, green: 0.26, blue: 0.8), Color(red: 1, green: 0.5, blue: 0.47)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            notchShape
                .frame(width: 360)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: claude.activity)
    }

    private var notchShape: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Circle()
                    .fill(phaseColor)
                    .frame(width: 9, height: 9)
                    .shadow(color: phaseColor.opacity(0.9), radius: 5)
                Text(claude.activity?.headline ?? locale.dn("home.preview.idle", fallback: "Notch is idle"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let project = claude.activity?.project, !project.isEmpty {
                    Text(project)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            Text(previewDetail)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(
            UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24, style: .continuous)
                .fill(Color(red: 0.03, green: 0.03, blue: 0.05))
        )
    }

    private var previewDetail: String {
        if let activity = claude.activity {
            if let tool = activity.toolDetail { return tool }
            if !activity.detail.isEmpty { return activity.detail }
            return activity.headline
        }
        return isClaudeEnabled
            ? locale.dn("home.preview.waiting", fallback: "Waiting for Claude Code to do something…")
            : locale.dn("home.preview.disabled", fallback: "Turn on Claude activity to see live narration here.")
    }

    private var phaseColor: Color {
        switch claude.activity?.phase {
        case .working: return .purple
        case .waiting: return .orange
        case .done: return .green
        case nil: return .gray
        }
    }

    // MARK: Claude

    private var claudeCard: some View {
        HStack(spacing: 14) {
            SettingsIconBadge(
                systemImage: "sparkle",
                tint: .purple,
                size: 38,
                iconSize: 18,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(locale.dn("menuBar.claudeActivity", fallback: "Show Claude Activity"))
                    .font(.system(size: 14, weight: .semibold))
                Text(locale.dn("home.claude.subtitle", fallback: "See what Claude Code is doing, live in the notch."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isClaudeEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(14)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Shortcuts

    private var shortcutGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(locale.dn("home.shortcuts", fallback: "Customize"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(shortcuts) { section in
                    Button {
                        SettingsWindowController.shared.showWindow(selecting: section)
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIconBadge(
                                systemImage: section.systemImage,
                                tint: section.tint,
                                size: 28,
                                iconColor: section.iconColor,
                                iconSize: 14,
                                cornerRadius: 8,
                                stroke: section.stroke
                            )
                            Text(section.localizedTitle(locale: locale))
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button {
                updater.checkForUpdates()
            } label: {
                Label(locale.dn("menuBar.checkForUpdates", fallback: "Check for Updates"), systemImage: "arrow.down.circle")
            }
            .disabled(!updater.canCheckForUpdates)

            Spacer()

            Button {
                SettingsWindowController.shared.showWindow()
            } label: {
                Label(locale.dn("menuBar.settings", fallback: "Settings"), systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        .controlSize(.regular)
    }

    private var background: some View {
        Color(nsColor: .windowBackgroundColor)
    }
}
