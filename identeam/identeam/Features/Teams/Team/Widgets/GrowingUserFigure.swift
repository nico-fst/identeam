import Kingfisher
import SwiftUI

struct GrowingUserFigure: View {
    let member: TeamMember

    @State private var userColor: Color = .accent
    @State private var phase: CGFloat = 0

    var body: some View {
        let progress =
            member.targetDays.isEmpty
            ? 0
            : CGFloat(member.idents.count) / CGFloat(member.targetDays.count)

        GrowingUserFigureLayout {
            head
        } torso: {
            GeometryReader { geometry in
                let metrics = GrowingUserFigureMetrics(size: geometry.size)
                let outline = RoundedRectangle(cornerRadius: metrics.cornerRadius)

                ZStack {
                    userColor.opacity(0.25)

                    WaveShape(
                        progress: progress,
                        phase: phase,
                        amplitude: metrics.waveAmplitude,
                        frequency: 1
                    )
                    .fill(
                        LinearGradient(
                            colors: [userColor, .clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .shadow(color: userColor.opacity(0.75), radius: metrics.shadowRadius)

                    WaveShape(
                        progress: progress,
                        phase: phase,
                        amplitude: metrics.waveAmplitude * 7 / 6,
                        frequency: 1.5
                    )
                    .fill(userColor.opacity(0.25))

                    Text("\(member.idents.count) / \(member.targetDays.count)")
                        .font(.system(size: metrics.fontSize, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, metrics.lineWidth * 2)
                }
                .clipShape(outline)
                .overlay {
                    outline.strokeBorder(userColor, lineWidth: metrics.lineWidth)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
        .task(id: member.user.avatar.key) {
            userColor = await UserColorFlash.getUserColor(
                image: RemoteImageReference(item: member.user.avatar)
            )
        }
    }

    @ViewBuilder
    private var head: some View {
        let resource = KF.ImageResource(
            downloadURL: member.user.avatar.url,
            cacheKey: member.user.avatar.key
        )

        GeometryReader { geometry in
            let metrics = GrowingUserFigureMetrics(size: geometry.size)

            KFImage(source: .network(resource))
                .placeholder {
                    ProgressView()
                }
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(userColor, lineWidth: metrics.lineWidth)
                }
        }
    }
}

#Preview {
    GrowingUserFigure(member: .templateGretaKanten)
}
