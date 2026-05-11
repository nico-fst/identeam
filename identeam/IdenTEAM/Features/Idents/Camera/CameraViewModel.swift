// Ref: https://www.youtube.com/watch?v=ik1QRc_kN9M&t=3733s

import SwiftUI
import Combine
import AVFoundation
import CoreLocation
import ImageIO

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let imageData: Data
}

class CameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    // SwiftUI vars
    @Published var isCapturingPhoto = false
    @Published var capturedImage: IdentifiableImage?
    @Published var isSessionRunning = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    
    @Published var zoomFactor: CGFloat = 1.0
    private let minZoomFactor: CGFloat = 1.0
    private let maxZoomFactor: CGFloat = 5.0
    
    // AVFoundation Components
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput? // since no initializer
    private let locationService = LocationService()
    
    // ensures expsneive camera actions don't block UI thread
    private let sessionQueue = DispatchQueue(label: "de.nicostern.identeam")
    
    override init() {
        super.init()
        locationService.requestAuthorizationIfNeeded()
    }
    
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationStatus = .authorized
            setupSession()
        case .notDetermined: // not authed => request permission
            authorizationStatus = .notDetermined
            // weak self: prohibits memory leak since treated as self? (may be freed)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { // since UI update
                    self?.authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        case .denied, .restricted: // restricted since has to be exhaustive
            authorizationStatus = .denied
        @unknown default: // for future Swift cases
            authorizationStatus = .denied
        }
    }
    
    // Config AVSetup
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // preset session
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            // filling currentInput
            // Self capitalized since static method: uses class, not instance
            guard let camera = Self.bestCamera(for: .back),
                  let input = try? AVCaptureDeviceInput(device: camera)
            else {
                print("ERROR accessing camera")
                self.session.commitConfiguration()
                return
            }
            if self.session.canAddInput(input) {
                self.session.addInput(input)
                self.currentInput = input
            }
            
            // filling photoOutput
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                
                // settings
                if let maxDimensions = camera.activeFormat.supportedMaxPhotoDimensions.last {
                    self.photoOutput.maxPhotoDimensions = maxDimensions
                }
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }
            
            self.session.commitConfiguration()
            self.session.startRunning() // start session
            
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
        }
    }
    
    func capturePhoto() {
        guard !isCapturingPhoto else { return }
        isCapturingPhoto = true
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // config photo settings
            let settings = AVCapturePhotoSettings()
            settings.flashMode = self.flashMode
            settings.photoQualityPrioritization = .quality
            settings.isHighResolutionPhotoEnabled = true
            
            // mirror and orient so taken photo matches the live feed
            if let connection = self.photoOutput.connection(with: .video) {
                connection.isVideoMirrored = self.currentInput?.device.position == .front
                connection.videoRotationAngle = Self.videoRotationAngleForCurrentDeviceOrientation()
            }
            
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("ERROR @ photo caputre: \(error.localizedDescription)")
            return
        }
        
        defer {
            DispatchQueue.main.async { [weak self] in
                self?.isCapturingPhoto = false
            }
        }
        
        guard let originalImageData = photo.fileDataRepresentation() else {
            print("ERROR converting photo to data")
            return
        }
        
        let imageData = PhotoMetadataHelper.addGPSLocation(
            locationService.currentLocation,
            to: originalImageData
        ) ?? originalImageData
        
        guard let uiImage = UIImage(data: imageData) else {
            print("ERROR converting photo data to preview image")
            return
        }
       
        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = IdentifiableImage(
                image: uiImage,
                imageData: imageData
            )
        }
    }
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // remove current input
            if let currentInput = self.currentInput {
                self.session.removeInput(currentInput)
            }
            
            // determine new camera position
            let currentPosition = self.currentInput?.device.position ?? .back
            let newPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
            
            // get new camera device
            guard let newCamera = Self.bestCamera(for: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newCamera)
            else {
                // failed to get new camera; restore old
                if let currentInput = self.currentInput,
                   self.session.canAddInput(currentInput) {
                    self.session.addInput(currentInput)
                }
                
                self.session.commitConfiguration()
                return
            }
            
            // add new camera input
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentInput = newInput
            }
            
            self.session.commitConfiguration()
        }
    }
    
    private static func bestCamera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        
        switch position {
        case .front:
            deviceTypes = [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera
            ]
        case .back:
            deviceTypes = [
                .builtInWideAngleCamera, // normal: x1, best quality
                .builtInDualWideCamera, // wide + ultra wide: better zoom, lense transition
                .builtInTripleCamera // uses all lenses
            ]
        default:
            deviceTypes = [
                .builtInWideAngleCamera
            ]
        }
        
        // scans -> available camera types
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        
        return discoverySession.devices.first
    }
    
    func toggleFlash() {
        flashMode = switch flashMode {
        case .off:
                .on
        case .on:
                .auto
        case .auto:
                .off
        @unknown default:
                .off
        }
    }
    
    func zoom(factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.currentInput?.device
            else { return }
            
            do {
                try device.lockForConfiguration() // required for changing device's props
                
                // clamp
                let clampedView = max(self.minZoomFactor, min(factor, min(self.maxZoomFactor, device.activeFormat.videoMaxZoomFactor)))
                
                device.videoZoomFactor = clampedView
                
                DispatchQueue.main.async {
                    self.zoomFactor = clampedView
                }
                
                device.unlockForConfiguration()
            } catch {
                print("ERROR zooming: \(error.localizedDescription)")
                return
            }
        }
    }
    
    private static func videoRotationAngleForCurrentDeviceOrientation() -> CGFloat {
        switch UIDevice.current.orientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        default:
            return 90
        }
    }
}

