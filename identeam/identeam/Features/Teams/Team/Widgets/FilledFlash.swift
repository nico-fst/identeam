import SwiftUI

struct FilledFlash: View {
    let progress: CGFloat
    let color: Color
    let text: String
    let animated: Bool

    @State private var phase: CGFloat = 0
    @State private var glowing = false

    var body: some View {
        GeometryReader { geo in
            let dynAmplitude = geo.size.height * 0.03
            let dynFrequency = geo.size.width * 0.002
            let dynLineWidth = max(1, min(geo.size.width, geo.size.height) * 0.015)

            ZStack {
                ZStack {
                    color.opacity(0.1)

                    WaveShape(
                        progress: progress,
                        phase: phase,
                        amplitude: dynAmplitude,
                        frequency: dynFrequency
                    )
                    .fill(
                        LinearGradient(
                            colors: [color, .clear],
                            startPoint: .bottom,
                            endPoint: .top)
                    )
                    .shadow(color: color.opacity(0.75), radius: 6)  // glow

                    WaveShape(
                        progress: progress,
                        phase: phase + 1.2,
                        amplitude: dynAmplitude + 1,
                        frequency: dynFrequency + 1
                    )
                    .fill(color.opacity(0.25))

                    Text(text)
                        .font(.custom("Nunito-Black", size: geo.size.height * 0.15))
                        .foregroundStyle(
                            color == AppColor.success
                                ? AppColor.onSuccess : AppColor.onAccent
                        )
                        .shadow(color: .black.opacity(0.25), radius: 5)  // glow
                }
                .mask {
                    Image("Flash")
                        .resizable()
                        .scaledToFill()
                }
                .overlay {
                    if progress > 0.95 {
                        // pulse outline
                        FlashShape()
                            .strokeBorder(color.opacity(0.75), lineWidth: dynLineWidth)
                            .aspectRatio(1, contentMode: .fill)
                            .scaleEffect(glowing ? 1.1 : 1.0)
                            .blur(radius: 7)
                            .animation(
                                .easeInOut(duration: 1.2)
                                    .repeatForever(autoreverses: true),
                                value: glowing
                            )
                    }
                }

                FlashShape()
                    .strokeBorder(color, lineWidth: dynLineWidth)
                    .aspectRatio(1, contentMode: .fill)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .onAppear {
            if animated {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }

                glowing = true
            }
        }
    }
}

struct WaveShape: Shape {
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

#Preview("50%") {
    HStack {
        ForEach([CGFloat(10), 50, 150], id: \.self) { height in
            FilledFlash(
                progress: 0.5,
                color: .accent,
                text: "3 / 5",
                animated: true
            )
            .frame(height: height)
        }
    }
}

#Preview("100%") {
    FilledFlash(
        progress: 1.0,
        color: .accent,
        text: "5 / 5",
        animated: true
    )
}
