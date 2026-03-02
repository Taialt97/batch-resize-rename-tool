import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ImageProcessingError: LocalizedError {
    case invalidSource
    case renderingFailed
    case exportFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidSource: return "Could not read source image"
        case .renderingFailed: return "Failed to render image"
        case .exportFailed: return "Failed to export PNG"
        }
    }
}

struct ImageProcessor {
    
    /// Synchronous processing — designed to be called from a background DispatchQueue.
    /// This avoids all async/actor overhead that can conflict with the main run loop.
    static func processImageSync(
        sourceURL: URL,
        targetSize: CGSize,
        outputURL: URL
    ) -> Result<Void, Error> {
        do {
            guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw ImageProcessingError.invalidSource
            }
            
            let width = Int(targetSize.width)
            let height = Int(targetSize.height)
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                throw ImageProcessingError.renderingFailed
            }
            
            // Aspect Fit calculation
            let sourceWidth = CGFloat(cgImage.width)
            let sourceHeight = CGFloat(cgImage.height)
            let scaleFactor = min(targetSize.width / sourceWidth, targetSize.height / sourceHeight)
            
            let scaledWidth = sourceWidth * scaleFactor
            let scaledHeight = sourceHeight * scaleFactor
            let x = (targetSize.width - scaledWidth) / 2.0
            let y = (targetSize.height - scaledHeight) / 2.0
            
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight))
            
            guard let resultImage = context.makeImage() else {
                throw ImageProcessingError.renderingFailed
            }
            
            guard let destination = CGImageDestinationCreateWithURL(
                outputURL as CFURL,
                UTType.png.identifier as CFString,
                1, nil
            ) else {
                throw ImageProcessingError.exportFailed
            }
            
            CGImageDestinationAddImage(destination, resultImage, nil)
            
            if !CGImageDestinationFinalize(destination) {
                throw ImageProcessingError.exportFailed
            }
            
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
