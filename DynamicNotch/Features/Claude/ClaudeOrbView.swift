import SwiftUI

/// Animated status mark for the Claude notch: orbiting sparks while working,
/// an expanding ripple while waiting, and a drawn checkmark when done.
struct ClaudeOrbView: View {
    let phase: ClaudePhase
    var size: CGFloat = 26

    @State private var doneStart = Date()

    private let accent = Color(red: 0.85, green: 0.47, blue: 0.34)
    private let hot = Color(red: 1.0, green: 0.68, blue: 0.45)

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                switch phase {
                case .working: working(t)
                case .waiting: waiting(t)
                case .done: done(context.date.timeIntervalSince(doneStart))
                }
            }
            .frame(width: size, height: size)
        }
        .onChange(of: phase) { _, newValue in
            if newValue == .done { doneStart = Date() }
        }
        .onAppear { if phase == .done { doneStart = Date() } }
        .accessibilityHidden(true)
    }

    // MARK: Working - breathing core with three comet-tailed sparks orbiting it

    private func working(_ t: TimeInterval) -> some View {
        let breathe = 0.5 + 0.5 * sin(t * 3.2)
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [hot.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: size * 0.55))
                .scaleEffect(0.85 + 0.25 * breathe)

            Image(systemName: "sparkle")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(hot)
                .scaleEffect(0.9 + 0.2 * breathe)
                .rotationEffect(.degrees(t * 90))

            ForEach(0..<3, id: \.self) { index in
                orbitSpark(t: t, index: index)
            }
        }
    }

    private func orbitSpark(t: TimeInterval, index: Int) -> some View {
        let radius = size * 0.42
        let base = t * 3.6 + Double(index) * (2 * .pi / 3)
        return ZStack {
            // fading tail
            ForEach(1..<5, id: \.self) { step in
                let angle = base - Double(step) * 0.22
                Circle()
                    .fill(accent.opacity(0.5 - Double(step) * 0.1))
                    .frame(width: size * 0.12 * (1 - Double(step) * 0.14), height: size * 0.12 * (1 - Double(step) * 0.14))
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
            Circle()
                .fill(hot)
                .frame(width: size * 0.15, height: size * 0.15)
                .shadow(color: hot.opacity(0.9), radius: 3)
                .offset(x: cos(base) * radius, y: sin(base) * radius)
        }
    }

    // MARK: Waiting - two staggered ripples around a steady dot

    private func waiting(_ t: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                let progress = (t * 0.9 + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
                Circle()
                    .stroke(Color.yellow.opacity(1 - progress), lineWidth: 2 - progress)
                    .scaleEffect(0.3 + progress * 0.75)
            }
            Circle()
                .fill(Color.yellow)
                .frame(width: size * 0.26, height: size * 0.26)
                .shadow(color: .yellow.opacity(0.8), radius: 4)
                .scaleEffect(1 + 0.12 * sin(t * 6))
        }
    }

    // MARK: Done - ring closes, checkmark draws itself, one burst of rays

    private func done(_ elapsed: TimeInterval) -> some View {
        let ring = min(elapsed / 0.35, 1)
        let check = min(max((elapsed - 0.25) / 0.3, 0), 1)
        let burst = min(max((elapsed - 0.5) / 0.5, 0), 1)
        return ZStack {
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(Color.green.opacity(burst > 0 ? 1 - burst : 0))
                    .frame(width: 1.5, height: size * 0.14)
                    .offset(y: -size * (0.42 + 0.16 * burst))
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            Circle()
                .trim(from: 0, to: ring)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(size * 0.1)
            CheckShape()
                .trim(from: 0, to: check)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .padding(size * 0.3)
        }
    }
}

private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
