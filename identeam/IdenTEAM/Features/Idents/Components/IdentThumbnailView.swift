import SwiftUI

struct IdentThumbnailView: View {
    let image: RemoteImageReference
    let avatar: RemoteImageReference
    let showImage: Bool

    var body: some View {
        if showImage {
            IdentImageView(image: image)
        } else {
            UserColorFlash(avatar: avatar)
        }
    }
}
