import SwiftUI

struct GrowingUserFigureMetrics {
    let size: CGSize

    private var scale: CGFloat { max(0, min(size.width, size.height)) / 90 }

    var lineWidth: CGFloat { 2 * scale }
    var cornerRadius: CGFloat { 24 * scale }
    var shadowRadius: CGFloat { 6 * scale }
    var fontSize: CGFloat { 17 * scale }
    // Frequency already counts waves across the available width in WaveShape.
    var waveAmplitude: CGFloat { min(3 * scale, max(0, size.height) / 12) }
}

extension View {
    func relativeFigureHeight(targetCount: Int, maximumTargetCount: Int) -> some View {
        let fraction =
            maximumTargetCount > 0
            ? CGFloat(targetCount) / CGFloat(maximumTargetCount)
            : 1

        return GeometryReader { geometry in
            self
                .frame(height: geometry.size.height * fraction)
                .clipped()
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct GrowingUserFigureLayout<Head: View, Torso: View>: View {
    @ViewBuilder let head: Head
    @ViewBuilder let torso: Torso

    var body: some View {
        // The parent supplies the height; the figure has no intrinsic height.
        GeometryReader { geometry in
            let figureWidth = min(60, geometry.size.width)
            let diameter = figureWidth * 0.8
            let spacing = min(diameter * 20 / 90, geometry.size.height * 0.05)

            VStack(spacing: spacing) {
                head
                    .frame(width: diameter, height: diameter)
                torso
                    .frame(width: figureWidth, height: geometry.size.height - diameter - spacing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
