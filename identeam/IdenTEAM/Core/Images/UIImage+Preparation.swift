import UIKit

extension UIImage {
    func centerSquareCropped() -> UIImage {
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

    func normalizedJPEGData(compressionQuality: CGFloat) -> Data? {
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

