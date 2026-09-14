import SwiftUI
import Kingfisher

struct UserColorFlash: View {
    let avatar: RemoteImageReference

    @State private var userColor: Color?

    var body: some View {
        Group {
            if let userColor {
                Image("Flash")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFill()
                    .foregroundStyle(userColor.opacity(0.7))
            } else {
                ProgressView()
            }
        }
        .task(id: avatar.key) {
            userColor = await getUserColor()
        }
    }
    private func getCachedImage(for item: RemoteImageReference) async -> UIImage? {
        await withCheckedContinuation { continuation in
            ImageCache.default.retrieveImage(
                forKey: item.key
            ) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value.image)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func getUserColor() async -> Color {
        guard let avatar = await getCachedImage(for: avatar)
        else {
            return .accent
        }

        return Color(
            uiColor: avatar.averageColor?.adjustedForUI() ?? .accent
        )
    }

}
