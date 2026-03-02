import Foundation
import Combine
import SwiftUI
import ImageIO
import CoreGraphics

class ViewModel: ObservableObject {
    
    // Global settings — stored as Strings so TextFields bind directly without formatting overhead
    @Published var globalTargetWidth: String = "460"
    @Published var globalTargetHeight: String = "360"
    @Published var globalPrefix: String = ""
    @Published var globalSuffix: String = ""
    
    @Published var items: [ImageItem] = []
    
    // Processing state
    @Published var isProcessing: Bool = false
    @Published var processedCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var processingMessage: String = ""
    @Published var showSuccessAlert: Bool = false
    
    // File importer state
    @Published var showingFileImporter: Bool = false
    @Published var showingFolderPicker: Bool = false
    
    func addFiles(urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard ["png", "jpg", "jpeg", "tiff", "tif", "heic", "gif", "bmp"].contains(ext) else { continue }
            
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Double,
                  let height = properties[kCGImagePropertyPixelHeight] as? Double else { continue }
            
            let originalName = url.deletingPathExtension().lastPathComponent
            let newItem = ImageItem(
                originalURL: url,
                originalName: originalName,
                originalSize: CGSize(width: width, height: height)
            )
            items.append(newItem)
        }
    }
    
    func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    func processAll(destinationDirectory: URL) {
        guard !items.isEmpty else { return }
        
        isProcessing = true
        processedCount = 0
        totalCount = items.count
        processingMessage = "Starting batch process..."
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let outputFolder = destinationDirectory.appendingPathComponent("Processed_Images_\(timestamp)")
        
        do {
            try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        } catch {
            processingMessage = "Failed to create directory: \(error.localizedDescription)"
            isProcessing = false
            return
        }
        
        // Snapshot all work items before going to background
        let workItems: [(index: Int, sourceURL: URL, targetSize: CGSize, outputURL: URL)] = (0..<items.count).compactMap { i in
            let item = items[i]
            let width = item.getEffectiveWidth(globalWidth: globalTargetWidth)
            let height = item.getEffectiveHeight(globalHeight: globalTargetHeight)
            let targetSize = CGSize(width: width, height: height)
            
            let name = item.getEffectiveName(globalPrefix: globalPrefix, globalSuffix: globalSuffix)
            let finalName = name.isEmpty ? item.originalName : name
            let outputURL = outputFolder.appendingPathComponent(finalName).appendingPathExtension("png")
            
            return (i, item.originalURL, targetSize, outputURL)
        }
        
        // Mark all as processing
        for i in 0..<items.count {
            items[i].status = .processing
        }
        
        // Process on a background queue, update UI on main
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var successCount = 0
            
            for work in workItems {
                let result = ImageProcessor.processImageSync(
                    sourceURL: work.sourceURL,
                    targetSize: work.targetSize,
                    outputURL: work.outputURL
                )
                
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success:
                        self.items[work.index].status = .success
                        successCount += 1
                        self.processedCount = successCount
                    case .failure(let error):
                        self.items[work.index].status = .failure(error.localizedDescription)
                    }
                    self.processingMessage = "Processing \(self.processedCount)/\(self.totalCount)..."
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.processingMessage = "Done! Processed \(self.processedCount)/\(self.totalCount) images."
                self.isProcessing = false
                self.showSuccessAlert = true
            }
        }
    }
}
