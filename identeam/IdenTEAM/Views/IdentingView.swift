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

struct IdentingView: View {
    @EnvironmentObject private var cameraVM: CameraViewModel
    
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
            if cameraVM.authorizationStatus == .authorized {
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
                            .allowsHitTesting(false)
                    }
                
                // camera controls
                VStack {
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
                .sheet(item: $cameraVM.capturedImage ) { item in
                    IdentingPhotoPreview(item: item, onDismiss: {
                        cameraVM.capturedImage = nil
                    })
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
    
    var body: some View {
        VStack {
            HStack {
                Button("Retake") {
                    onDismiss()
                }
                .padding()
                
                Spacer()
                
                Button("Save") {
                    // save photo to camera roll
                    PHPhotoLibrary.requestAuthorization { status in
                        guard status == .authorized || status == .limited else { return }
                        
                        PHPhotoLibrary.shared().performChanges {
                            let options = PHAssetResourceCreationOptions()
                            let creationRequest = PHAssetCreationRequest.forAsset()
                            
                            creationRequest.addResource(with: .photo, data: item.imageData, options: options)
                        }
                    }
                    onDismiss()
                }
            }
            
            Image(uiImage: item.image)
                .resizable()
                .scaledToFit()
                .mask(
                    Image("Flash")
                        .resizable()
                        .scaledToFit()
                )
            
            Spacer()
        }
    }
}

#Preview("IdentingView") {
    IdentingView()
        .environmentObject(CameraViewModel())
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
        onDismiss: {}
    )
}
