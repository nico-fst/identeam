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
