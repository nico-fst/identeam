import SwiftUI

/// The exact same water mask clips the fill and the inverted half of the numbers.
struct ProgressFlash: View {
    let completed: Int
    let target: Int
    let color: Color
    var dark: Bool?
    var animated = true
    var showsRatio = true
    @Environment(\.colorScheme) private var colorScheme
    var active = true
    @State private var level: CGFloat = 0

    private var progress: CGFloat {
        target > 0 ? min(1, max(0, CGFloat(completed) / CGFloat(target))) : 0
    }
    private var displayedLevel: CGFloat { animated ? level : progress }
    private var isDark: Bool { dark ?? (colorScheme == .dark) }

    var body: some View {
        let paused = !active || !animated
        TimelineView(.animation(minimumInterval: 1 / 30, paused: paused)) { timeline in
            GeometryReader { geometry in
                let phase = timeline.date.timeIntervalSinceReferenceDate * 1.6
                ZStack {
                    FlashShape().fill(color.opacity(0.16))
                    ProgressFlashWater(progress: displayedLevel, phase: phase, layer: .back)
                        .fill(color.opacity(0.45)).clipShape(FlashShape())
                    ProgressFlashWater(progress: displayedLevel, phase: phase, layer: .front)
                        .fill(color).clipShape(FlashShape())
                    FlashShape().stroke(color, lineWidth: 1.3)

                    if showsRatio {
                        // Completion label
                        ratio(size: geometry.size).foregroundStyle(color)  // normal color
                        ratio(size: geometry.size)  // complementary color masked by water
                            .foregroundStyle(
                                color.mix(
                                    with: isDark ? AppColor.Palette.ink : AppColor.Palette.cream,
                                    by: 0.84
                                )
                            )
                            .mask(
                                ProgressFlashWater(
                                    progress: displayedLevel, phase: phase, layer: .combined))
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { if active && animated { animateLevel() } }
        .onChange(of: progress) { if active && animated { animateLevel() } }
        .onChange(of: active) {
            if active && animated { animateLevel() } else { level = 0 }
        }
        .onChange(of: animated) { if active && animated { animateLevel() } }
    }

    private func animateLevel() {
        withAnimation(.easeInOut(duration: 0.85)) { level = progress }
    }

    private func ratio(size: CGSize) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text("\(completed)").font(.custom("Nunito-Black", size: size.height * 0.28))
            Text("/\(target)").font(.custom("Nunito-Black", size: size.height * 0.16))
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .position(x: size.width * 0.55, y: size.height * 0.53)
    }

}

struct ProgressFlashWater: Shape {
    enum Layer { case front, back, combined }
    var progress: CGFloat
    let phase: CGFloat
    let layer: Layer
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        if progress >= 1 { return Path(rect) }
        let front = ProgressFlashWave(
            progress: progress, phase: phase, amplitude: rect.height * 0.03,
            frequency: 1.1
        ).path(in: rect)
        let back = ProgressFlashWave(
            progress: progress, phase: phase + 1.2, amplitude: rect.height * 0.042,
            frequency: 1.8
        ).path(in: rect)
        switch layer {
        case .front: return front
        case .back: return back
        case .combined: return front.union(back)
        }
    }
}

private struct ProgressFlashWave: Shape {
    var progress: CGFloat
    var phase: CGFloat  // animates horizontal
    var amplitude: CGFloat  // height
    var frequency: CGFloat  // #waves

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let fillHeight = rect.height * (1 - progress)

        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))  // start bottom left
        path.addLine(to: CGPoint(x: 0, y: fillHeight))  // vertical line to fillHeight

        let step: CGFloat = 2  // draw left -> right
        for x in stride(from: CGFloat(0), through: rect.width, by: step) {
            let relativeX = x / rect.width  // normalizes x to 0...1
            // calculate next relative wave diff
            let angle = relativeX * .pi * 2 * frequency + phase  // .pi * 2 = 1 sinus period
            let y = fillHeight + sin(angle) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()

        return path
    }
}
