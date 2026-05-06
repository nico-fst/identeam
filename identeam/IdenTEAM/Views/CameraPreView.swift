// Ref: https://www.youtube.com/watch?v=ik1QRc_kN9M&t=3733s

import SwiftUI
import AVFoundation

// Wrapper from UIKit -> SwiftUI (so that this UIKIt-View is usable in SwiftUI)
struct CameraPreView: UIViewRepresentable {
    let session: AVCaptureSession
    let cameraVM: CameraViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero) // empty view
//         view.backgroundColor = .black
        
        // add previewLayer on empty view
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds // resize to device screen
        view.layer.addSublayer(previewLayer)
        
        // store layer in context
        context.coordinator.previewLayer = previewLayer
        
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        view.addGestureRecognizer(pinchGesture)
        
        context.coordinator.cameraVM = cameraVM
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    /// Stable Cache between recreation of views
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
        var lastZoomFactor: CGFloat = 1.0
        var cameraVM: CameraViewModel?
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let cameraVM = cameraVM else { return }
            
            switch gesture.state {
            case .began:
                lastZoomFactor = cameraVM.zoomFactor
            case .changed:
                let newZoom = lastZoomFactor * gesture.scale
                cameraVM.zoom(factor: newZoom)
            default: break
            }
        }
    }
}
