import Foundation
import AppKit
import ImageIO

struct ImageFile: Identifiable, Equatable {
    let id = UUID()
    let originalURL: URL
    let originalName: String
    let pixelWidth: Int
    let pixelHeight: Int
    let thumbnail: NSImage?

    var overrideWidth: String = ""
    var overrideHeight: String = ""
    var overridePadding: String = ""
    var overrideNamePattern: String = ""
    var hasWidthOverride = false
    var hasHeightOverride = false
    var hasPaddingOverride = false
    var hasNamePatternOverride = false

    init(url: URL) {
        self.originalURL = url
        self.originalName = url.deletingPathExtension().lastPathComponent

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            self.pixelWidth = 0
            self.pixelHeight = 0
            self.thumbnail = nil
            return
        }

        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        self.pixelWidth = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
        self.pixelHeight = props?[kCGImagePropertyPixelHeight] as? Int ?? 0

        let thumbOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: 96,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts as CFDictionary) {
            self.thumbnail = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        } else {
            self.thumbnail = nil
        }
    }

    static func == (lhs: ImageFile, rhs: ImageFile) -> Bool { lhs.id == rhs.id }
}
