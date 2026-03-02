import AppKit
import CoreGraphics
import UniformTypeIdentifiers

enum ImageProcessingService {

    /// Scales the source image to fit within the canvas's inner safe area (canvas minus padding),
    /// centres it on a fully transparent canvas, and returns the composited CGImage.
    static func processImage(
        from url: URL,
        canvasWidth: Int,
        canvasHeight: Int,
        padding: Int
    ) -> CGImage? {
        guard let source = NSImage(contentsOf: url),
              let sourceCG = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        let origW = CGFloat(sourceCG.width)
        let origH = CGFloat(sourceCG.height)
        guard origW > 0, origH > 0 else { return nil }

        let cW = CGFloat(canvasWidth)
        let cH = CGFloat(canvasHeight)
        let pad = CGFloat(max(padding, 0))

        let safeW = max(cW - pad * 2, 1)
        let safeH = max(cH - pad * 2, 1)

        let scale = min(safeW / origW, safeH / origH)
        let scaledW = origW * scale
        let scaledH = origH * scale

        let offsetX = (cW - scaledW) / 2.0
        let offsetY = (cH - scaledH) / 2.0

        guard let ctx = CGContext(
            data: nil,
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.clear(CGRect(x: 0, y: 0, width: cW, height: cH))
        ctx.interpolationQuality = .high
        ctx.draw(sourceCG, in: CGRect(x: offsetX, y: offsetY, width: scaledW, height: scaledH))

        return ctx.makeImage()
    }

    /// Writes a CGImage to disk as PNG.
    static func savePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1, nil
        ) else { return false }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest)
    }
}
