import AVFoundation
import AVKit
import Photos
import SwiftData
import SwiftUI

struct IdentingView: View {
    @EnvironmentObject private var vm: AppVM
    @EnvironmentObject private var cameraVM: CameraVM
    @EnvironmentObject private var identingVM: IdentingVM
    @EnvironmentObject private var teamsVM: TeamsVM

    @Environment(\.modelContext) private var modelContext

    var forceCameraPreview: Bool = false

    private var flashIcon: String {
        switch cameraVM.flashMode {
        case .off:
            return "bolt.slash.fill"
        case .on:
            return "bolt.fill"
        case .auto:
            return "bolt.badge.automatic.fill"
        @unknown default:
            return "bolt.slash.fill"
        }
    }

    var body: some View {
        ZStack {
            if cameraVM.authorizationStatus == .authorized || forceCameraPreview {
                CameraPreView(session: cameraVM.session, cameraVM: cameraVM)
                    .ignoresSafeArea()
                    .overlay {
                        // outside of flash - darkened
                        Rectangle()
                            .fill(IgniteColor.cameraShade.opacity(0.5))
                            .ignoresSafeArea()
                            .overlay {
                                Image("Flash")
                                    .resizable()
                                    .scaledToFit()
                                    .scaleEffect(1.5)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                            .overlay {
                                FlashShape()
                                    .strokeBorder(.accent, lineWidth: 1)
                                    .scaleEffect(1.5)
                            }
                            .allowsHitTesting(false)
                    }

                // camera controls
                VStack {
                    TeamWheel(
                        textColor: IgniteColor.cameraText,
                        selectedTeamSlug: $identingVM.selectedTeamSlug
                    )
                    .frame(width: 300, height: 110)
                    .disabled(identingVM.isUploadingImage)

                    Spacer()  // at bottom of screen

                    // toggleFlash - capturePhoto - switchCamera
                    HStack(spacing: 15) {
                        Button {
                            cameraVM.toggleFlash()
                        } label: {
                            Image(systemName: flashIcon)
                                .font(.nunito(.largeTitle))
                                .frame(width: 70, height: 70)
                                .foregroundStyle(IgniteColor.cameraText)
                        }

                        Button {
                            cameraVM.capturePhoto()
                        } label: {
                            Circle()
                                .strokeBorder(IgniteColor.cameraText, lineWidth: 3)
                                .opacity(0.8)
                                .frame(width: 70, height: 70)
                                .overlay {
                                    if cameraVM.isCapturingPhoto {
                                        ProgressView()
                                            .tint(IgniteColor.cameraText)
                                    } else {
                                        Circle()
                                            .fill(IgniteColor.cameraText)
                                            .frame(width: 60, height: 60)
                                    }
                                }
                        }
                        .disabled(cameraVM.isCapturingPhoto)

                        Button {
                            cameraVM.switchCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.nunito(.largeTitle))
                                .frame(width: 70, height: 70)
                                .foregroundStyle(IgniteColor.cameraText)
                        }
                    }
                    .padding(.bottom, 30)
                }
                .sheet(item: $cameraVM.capturedImage) { item in
                    NavigationStack {
                        IdentingPhotoPreview(item: item) {
                            // onDismiss
                            cameraVM.capturedImage = nil
                            identingVM.uploadError = nil
                            identingVM.createIdentUserText = ""
                        } onUpload: {
                            let didUpload = await identingVM.tryCreatingIdentWithImage(
                                image: item,
                                vm: vm,
                                ctx: modelContext,
                                teamsVM: teamsVM
                            )
                            if didUpload {
                                cameraVM.capturedImage = nil
                            }
                        }
                    }
                }
            } else {
                VStack {
                    Image(systemName: "camera.fill")
                        .font(.nunito(.largeTitle))
                        .opacity(0.3)
                    Text("Camera Access Required")
                        .opacity(0.3)

                    if cameraVM.authorizationStatus == .denied {
                        Text("Please enable camera in settings:")
                        Button("Open Settings") {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accent)
                        .foregroundStyle(IgniteColor.onAccent)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            cameraVM.checkAuthorization()
        }
    }
}

struct IdentingPhotoPreview: View {
    let item: IdentifiableImage
    let onDismiss: () -> Void
    let onUpload: () async -> Void

    @State private var savedImagetoCameraRoll = false

    @EnvironmentObject private var identingVM: IdentingVM
    @EnvironmentObject private var vm: AppVM

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            VStack {
                TeamWheel(
                    textColor: IgniteColor.text,
                    selectedTeamSlug: $identingVM.selectedTeamSlug
                )
                .frame(width: 300, height: 110)
                .disabled(identingVM.isUploadingImage)

                Image(uiImage: item.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)  // frame crucial for 3Deffect
                    .clipped()
                    .mask(
                        Image("Flash")
                            .resizable()
                            .scaledToFit()
                    )
                    .overlay {
                        FlashShape()
                            .strokeBorder(.accent, lineWidth: 1)
                    }
                    .modifier(
                        Floating3DEffect(
                            isActive: true,
                            animationFactor: 1,
                            showShadow: true
                        )
                    )
                    .padding(.bottom, 75)
            }

            VStack {
                Spacer()

                TextField(
                    "Tell your members about what's going on...",
                    text: $identingVM.createIdentUserText,
                    axis: .vertical
                )
                .padding()  // simulating List{TextField} style
                .background {
                    RoundedRectangle(cornerRadius: 50)
                        .fill(IgniteColor.surface)
                }
                .lineLimit(1...2)
                .disabled(identingVM.isUploadingImage)

                Text(identingVM.uploadError ?? "")
                    .foregroundStyle(IgniteColor.error)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .igniteColors()
        .navigationTitle("New Ident")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // left: X
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .disabled(identingVM.isUploadingImage)
            }

            // right: Save; Upload
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    savePhotoToCameraRoll()
                    savedImagetoCameraRoll = true
                } label: {
                    if !savedImagetoCameraRoll {
                        Image(systemName: "square.and.arrow.down")
                    } else {
                        Image(systemName: "square.and.arrow.down.fill")
                    }
                }
                .disabled(identingVM.isUploadingImage || savedImagetoCameraRoll)

                Button {
                    Task {
                        await onUpload()
                    }
                } label: {
                    if identingVM.isUploadingImage {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                            .foregroundStyle(IgniteColor.onAccent)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.accent)
                .foregroundStyle(IgniteColor.onAccent)
                .disabled(identingVM.isUploadingImage)
            }
        }
        .interactiveDismissDisabled(identingVM.isUploadingImage)
        .alert("Weekly target reminder", isPresented: $identingVM.showMissingTargetWarning) {
            Button("Upload without target") {
                identingVM.resolveMissingTargetWarning(continueUpload: true)
            }
            Button("Cancel", role: .cancel) {
                identingVM.resolveMissingTargetWarning(continueUpload: false)
            }
        } message: {
            Text(
                "Remember to set your weekly target by Monday. You can still upload this Ident without a target."
            )
        }
        .onDisappear {
            identingVM.resolveMissingTargetWarning(continueUpload: false)
        }
        .sheet(isPresented: $identingVM.isSettingTarget) {
            if let slug = identingVM.selectedTeamSlug {
                NavigationStack {
                    TargetPicker(slug: slug, referenceDate: Date()) { _ in
                        identingVM.isSettingTarget = false
                    }
                }
            }
        }
    }

    private func savePhotoToCameraRoll() {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }

            PHPhotoLibrary.shared().performChanges {
                let options = PHAssetResourceCreationOptions()
                let creationRequest = PHAssetCreationRequest.forAsset()

                creationRequest.addResource(with: .photo, data: item.imageData, options: options)
            }
        }
    }
}

#Preview("IdentingView - Camera") {
    IdentingView(forceCameraPreview: true)
        .environmentObject(AppVM())
        .environmentObject(CameraVM())
        .environmentObject(TeamsVM())
        .environmentObject(IdentingVM())
}

#Preview("IdentingView - No Camera") {
    IdentingView(forceCameraPreview: false)
        .environmentObject(AppVM())
        .environmentObject(CameraVM())
        .environmentObject(TeamsVM())
        .environmentObject(IdentingVM())
}

#Preview("IdentingPhotoPreview") {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
    let image = renderer.image { context in
        UIColor.red.setFill()
        context.fill(CGRect(origin: .zero, size: CGSize(width: 300, height: 300)))
    }

    IdentingPhotoPreview(
        item: IdentifiableImage(
            image: image,
            imageData: image.jpegData(compressionQuality: 1)!
        ),
        onDismiss: {},
        onUpload: {}
    )
    .environmentObject(IdentingVM())
    .environmentObject(AppVM())
}
