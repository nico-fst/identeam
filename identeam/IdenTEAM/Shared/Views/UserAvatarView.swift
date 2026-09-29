import SwiftUI
import Kingfisher

struct UserAvatarView: View {
    let image: RemoteImageReference

    var body: some View {
        let resource = KF.ImageResource(
            downloadURL: image.url,
            cacheKey: image.key
        )

        KFImage(source: .network(resource))
            .placeholder {
                ProgressView()
            }
            .resizable()
            .scaledToFill()
            .clipShape(Circle())
    }
}

struct FilledUserAvatar: View {
    let image: RemoteImageReference
    let progress: CGFloat

    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            UserAvatarView(image: image)
                .opacity(0.25)

            UserAvatarView(image: image)
                .mask {
                    WaveShape(
                        progress: progress,
                        phase: phase,
                        amplitude: 1,
                        frequency: 1.5
                    )
                }
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                phase = .pi * 2
            }
        }
    }
}
