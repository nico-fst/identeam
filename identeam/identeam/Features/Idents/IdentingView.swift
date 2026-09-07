//
//  IdentView.swift
//  identeam
//
//  Created by Nico Stern on 06.05.26.
//

import SwiftUI
import AVFoundation
import AVKit
import Photos
import SwiftData

struct IdentingView: View {
    @EnvironmentObject private var vm: AppViewModel
    @EnvironmentObject private var cameraVM: CameraViewModel
    @EnvironmentObject private var identingVM: IdentingViewModel
    @EnvironmentObject private var teamsVM: TeamsViewModel
    
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
            if cameraVM.authorizationStatus == .authorized ||
                forceCameraPreview
            {
                CameraPreView(session: cameraVM.session, cameraVM: cameraVM)
                    .ignoresSafeArea()
                    .overlay {
                        // outside of flash - darkened
                        Rectangle()
                            .fill(.black.opacity(0.5))
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
                                Image("FlashOutline")
                                    .renderingMode(.template) // renders all pixels as foreground color
                                    .resizable()
                                    .scaledToFit()
                                    .scaleEffect(1.5)
                                    .foregroundStyle(.accent)
                            }
                            .allowsHitTesting(false)
                    }
                
                // camera controls
                VStack {
                    TeamWheel(textColor: .white, selectedTeamSlug: $identingVM.selectedTeamSlug)
                        .frame(width: 300, height: 110)
                .disabled(identingVM.isUploadingImage)
                    
                    Spacer() // at bottom of screen
                    
                    // toggleFlash - capturePhoto - switchCamera
                    HStack(spacing: 15) {
                        Button {
                            cameraVM.toggleFlash()
                        } label: {
                            Image(systemName: flashIcon)
                                .font(.largeTitle)
                                .frame(width: 70, height: 70)
                                .foregroundStyle(.white)
                        }
                        
                        Button {
                            cameraVM.capturePhoto()
                        } label: {
                            Circle()
                                .strokeBorder(.white, lineWidth: 3)
                                .opacity(0.8)
                                .frame(width: 70, height: 70)
                                .overlay {
                                    if cameraVM.isCapturingPhoto {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 60, height: 60)
                                    }
                                }
                        }
                        .disabled(cameraVM.isCapturingPhoto)
                        
                        Button {
                            cameraVM.switchCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.largeTitle)
                                .frame(width: 70, height: 70)
                                .foregroundStyle(.white)
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
                        .font(.largeTitle)
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
    
    @EnvironmentObject private var identingVM: IdentingViewModel
    @EnvironmentObject private var vm: AppViewModel
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack() {
            VStack {
                TeamWheel(textColor: colorScheme == .dark ? .white : .black,
                          selectedTeamSlug: $identingVM.selectedTeamSlug)
                .frame(width: 300, height: 110)
                .disabled(identingVM.isUploadingImage)
                
                Image(uiImage: item.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity) // frame crucial for 3Deffect
                    .clipped()
                    .mask(
                        Image("Flash")
                            .resizable()
                            .scaledToFit()
                    )
                    .overlay {
                        Image("FlashOutline")
                            .renderingMode(.template) // renders all pixels as foreground color
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.accent)
                    }
                    .modifier(Floating3DEffect(isActive: true, animationFactor: 1))
                    .padding(.bottom, 75)
            }
            
            VStack {
                Spacer()
                
                TextField(
                    "Tell your members about what's going on...",
                    text: $identingVM.createIdentUserText,
                    axis: .vertical
                )
                .padding() // simulating List{TextField} style
                .background {
                    RoundedRectangle(cornerRadius: 50)
                        .fill(.gray.opacity(0.15))
                }
                .lineLimit(1...2)
                .disabled(identingVM.isUploadingImage)
                
                Text(identingVM.uploadError ?? "")
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                    }
                }
                .buttonStyle(.borderedProminent)
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
            Text("Remember to set your weekly target by Monday. You can still upload this Ident without a target.")
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
        .environmentObject(AppViewModel())
        .environmentObject(CameraViewModel())
        .environmentObject(TeamsViewModel())
        .environmentObject(IdentingViewModel())
}

#Preview("IdentingView - No Camera") {
    IdentingView(forceCameraPreview: false)
        .environmentObject(AppViewModel())
        .environmentObject(CameraViewModel())
        .environmentObject(TeamsViewModel())
        .environmentObject(IdentingViewModel())
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
    .environmentObject(IdentingViewModel())
    .environmentObject(AppViewModel())
}
