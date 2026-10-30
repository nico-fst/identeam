import SwiftUI

/// The exact same water mask clips the fill and the inverted half of the numbers.
struct TeamWeekProgressFlash: View {
    let completed: Int
    let target: Int
    let color: Color
    var dark = false
    var active = true
    @State private var level: CGFloat = 0

    private var progress: CGFloat { target > 0 ? min(1, CGFloat(completed) / CGFloat(target)) : 0 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !active)) { timeline in
            GeometryReader { geometry in
                let phase = timeline.date.timeIntervalSinceReferenceDate * 1.6
                ZStack {
                    FlashShape().fill(color.opacity(0.16))
                    TeamWeekWater(progress: level, phase: phase, layer: .back)
                        .fill(color.opacity(0.45)).clipShape(FlashShape())
                    TeamWeekWater(progress: level, phase: phase, layer: .front)
                        .fill(color).clipShape(FlashShape())
                    FlashShape().stroke(color, lineWidth: 1.3)

                    // Completion label
                    ratio(size: geometry.size).foregroundStyle(color)  // normal color
                    ratio(size: geometry.size)  // complementary color masked by water
                        .foregroundStyle(
                            color.mix(
                                with: dark ? AppColor.Palette.ink : AppColor.Palette.cream, by: 0.84
                            )
                        )
                        .mask(TeamWeekWater(progress: level, phase: phase, layer: .combined))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { if active { animateLevel() } }
        .onChange(of: progress) { if active { animateLevel() } }
        .onChange(of: active) {
            if active { animateLevel() } else { level = 0 }
        }
    }

    private func animateLevel() {
        withAnimation(.easeInOut(duration: 0.85)) { level = progress }
    }

    private func ratio(size: CGSize) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text("\(completed)").font(TeamWeekStyle.font(size.height * 0.28, heavy: true))
            Text("/\(target)").font(TeamWeekStyle.font(size.height * 0.16, heavy: true))
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .position(x: size.width * 0.55, y: size.height * 0.53)
    }

}

private struct TeamWeekWater: Shape {
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
        let front = WaveShape(
            progress: progress, phase: phase, amplitude: rect.height * 0.03,
            frequency: 1.1
        ).path(in: rect)
        let back = WaveShape(
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
