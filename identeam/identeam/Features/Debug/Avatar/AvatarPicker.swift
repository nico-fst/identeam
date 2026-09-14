import SwiftUI
import SwiftData
import PhotosUI
import Kingfisher

struct AvatarPicker: View {
    @State private var avatarImage: IdentifiableImage?
    @State private var selectedItem: PhotosPickerItem?

    @EnvironmentObject private var avatarVM: AvatarViewModel

    @Environment(\.modelContext) private var ctx

    @Query(filter: #Predicate<S3Item> {
        $0.kindRaw == "ownAvatar"
    }) private var avatars: [S3Item]


    @AppStorage("nickname") private var nickname: String?
    @AppStorage("username") private var username: String?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
            avatarContent
        }
        .sheet(item: $avatarImage) { avatar in
            NavigationStack {
                VStack() {
                    Text("Upload new Avatar")
                        .font(.largeTitle)

                    Spacer()

                    Image(uiImage: avatar.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 350, height: 350)
                        .clipShape(Circle())

                    Spacer()

                    Text(avatarVM.uploadError ?? "")
                        .foregroundStyle(.red)

                    Spacer()

                    Text("There is no cropper yet.\nJust use a squared image :)")
                        .multilineTextAlignment(.center)
                }
                .padding()
                .toolbar {
                    // left: X
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                           avatarImage  = nil
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }

                    // right: Save
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task {
                                let didUpload = await avatarVM.propagateAvatarUpdate(
                                    avatar,
                                    avatars: avatars,
                                    ctx: ctx
                                )
                                if didUpload {
                                    avatarImage = nil
                                    selectedItem = nil
                                }
                            }
                        } label: {
                            if avatarVM.isUploadingAvatar {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(avatarVM.isUploadingAvatar)
                    }
                }
            }
        }
        .onAppear() {
            Task {
                try? await avatarVM.refreshAvatarIfNeeded(avatars: avatars, ctx: ctx)
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                guard let newItem,
                      let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else { return }

                // crop & convert to jpeg
                let croppedImage = image.centerSquareCropped()
                guard let jpegData = croppedImage.normalizedJPEGData(compressionQuality: 0.85) else { return }

                avatarImage = IdentifiableImage(image: croppedImage, imageData: jpegData)
            }
        }
    }

    // umgeht, dass im PhotoPicker exakt 1 View Typ sein muss (baut conditional)
    @ViewBuilder
    private var avatarContent: some View {
        HStack(spacing: 24) {
            if let avatar = avatars.first {
                let resource = KF.ImageResource(
                    downloadURL: avatar.url,
                    cacheKey: avatar.key
                )


                KFImage(source: .network(resource))
                    .placeholder {
                        ProgressView()
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .foregroundStyle(.secondary)
            }

            // always render nickname und username
            VStack(alignment: .leading) {
                Text(nickname ?? "no nickname")
                    .font(.largeTitle)
                Text("@\(username ?? "no username")")
                    .font(.footnote)
                    .opacity(0.6)
            }
        }
    }

}

#Preview {
    AvatarPicker()
        .environmentObject(AvatarViewModel())
}
