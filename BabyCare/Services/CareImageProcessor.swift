import UIKit
import ImageIO

/// Decode only the pixels needed for display, including large camera/HEIC images.
enum CareImageProcessor {
    static func thumbnail(_ data: Data, maximumPixels: Int) -> UIImage? {
        guard maximumPixels > 0,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixels,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    static func jpeg(_ data: Data, avatar: Bool = false) -> Data? {
        guard let image = thumbnail(data, maximumPixels: avatar ? 800 : 1600) else { return nil }
        let output: UIImage
        if avatar {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            output = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: format).image { _ in
                let ratio = max(400 / image.size.width, 400 / image.size.height)
                let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                image.draw(in: CGRect(x: (400 - size.width) / 2, y: (400 - size.height) / 2,
                                      width: size.width, height: size.height))
            }
        } else { output = image }
        guard let result = output.jpegData(compressionQuality: 0.82),
              result.count <= CloudMediaPlan.maximumBytes else { return nil }
        return result
    }
}
