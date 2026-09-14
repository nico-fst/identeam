import UIKit
import CoreImage

extension UIImage {
    /// Scales down provided image to 1x1 for an user representing color
    var averageColor: UIColor? {
        guard let ciImage = CIImage(image: self) else { return nil }

        let extent = ciImage.extent

        let filter = CIFilter(name: "CIAreaAverage")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter?.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)

        let context = CIContext(options: [
            .workingColorSpace: kCFNull!
        ])

        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: CGFloat(bitmap[3]) / 255
        )
    }
}

extension UIColor {
    /// ensure color is usable in UI
    func adjustedForUI() -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &alpha
        ) else {
            return self
        }

        return UIColor(
            hue: hue,
            saturation: max(saturation, 0.45),
            brightness: min(max(brightness, 0.55), 0.85),
            alpha: alpha
        )
    }
}

