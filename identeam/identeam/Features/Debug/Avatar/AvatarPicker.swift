//
//  AvatarPicker.swift
//  identeam
//
//  Created by Nico Stern on 09.05.26.
//

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
        $0.kindRaw == "avatar"
    }) private var avatars: [S3Item]
    
    
    @AppStorage("fullName") private var fullName: String?
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
            
            // always render fullname und username
            VStack(alignment: .leading) {
                Text(fullName ?? "no fullname")
                    .font(.largeTitle)
                Text("@\(username ?? "no username")")
                    .font(.footnote)
                    .opacity(0.6)
            }
        }
    }
    
}

extension UIImage {
    fileprivate func centerSquareCropped() -> UIImage {
        let originalSize = size
        let squareLength = min(originalSize.width, originalSize.height)

        let cropRect = CGRect(
            x: (originalSize.width - squareLength) / 2,
            y: (originalSize.height - squareLength) / 2,
            width: squareLength,
            height: squareLength
        )

        guard let cgImage = self.cgImage?.cropping(to: cropRect) else {
            return self
        }

        return UIImage(
            cgImage: cgImage,
            scale: scale,
            orientation: imageOrientation
        )
    }

    fileprivate func normalizedJPEGData(compressionQuality: CGFloat) -> Data? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let normalizedImage = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }

        return normalizedImage.jpegData(compressionQuality: compressionQuality)
    }
}

#Preview {
    AvatarPicker()
        .environmentObject(AvatarViewModel())
}
