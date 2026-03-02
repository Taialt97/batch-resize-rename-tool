import Foundation
import CoreGraphics
import AppKit
import Combine

struct ImageItem: Identifiable, Equatable {
    let id = UUID()
    let originalURL: URL
    let originalName: String
    let originalSize: CGSize
    
    var overrideName: String = ""
    var overrideWidth: String = ""
    var overrideHeight: String = ""
    
    var status: ProcessingStatus = .pending
    
    enum ProcessingStatus: Equatable {
        case pending
        case processing
        case success
        case failure(String)
    }
    
    var displayOriginalSize: String {
        "\(Int(originalSize.width)) x \(Int(originalSize.height))"
    }
    
    func getEffectiveName(globalPrefix: String, globalSuffix: String) -> String {
        if !overrideName.isEmpty {
            return overrideName
        }
        return "\(globalPrefix)\(originalName)\(globalSuffix)"
    }
    
    func getEffectiveWidth(globalWidth: String) -> Double {
        if let w = Double(overrideWidth), w > 0 { return w }
        if let w = Double(globalWidth), w > 0 { return w }
        return 460
    }
    
    func getEffectiveHeight(globalHeight: String) -> Double {
        if let h = Double(overrideHeight), h > 0 { return h }
        if let h = Double(globalHeight), h > 0 { return h }
        return 360
    }
}
