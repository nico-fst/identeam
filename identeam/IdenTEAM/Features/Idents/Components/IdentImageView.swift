import SwiftUI
import Kingfisher

struct IdentImageView: View {
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
            .scaledToFit()
            .mask(
                Image("Flash")
                    .resizable()
                    .scaledToFill()
            )
    }
}
