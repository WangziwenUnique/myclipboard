import Foundation
import SwiftUI

struct ClipboardItem: Identifiable, Hashable, Codable {
    let id: UUID
    let content: String
    let type: ClipboardItemType
    let timestamp: Date
    let sourceApp: String
    var isFavorite: Bool
    let htmlContent: String?
    
    // 图片相关数据
    let imageData: Data?        // Base64 编码的图片数据
    let imageDimensions: String? // 图片尺寸信息
    let imageSize: Int64?       // 图片文件大小
    
    init(content: String, type: ClipboardItemType = .text, sourceApp: String = "Unknown", htmlContent: String? = nil, isFavorite: Bool = false, imageData: Data? = nil, imageDimensions: String? = nil, imageSize: Int64? = nil) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.sourceApp = sourceApp
        self.isFavorite = isFavorite
        self.htmlContent = htmlContent
        self.imageData = imageData
        self.imageDimensions = imageDimensions
        self.imageSize = imageSize
    }
    
    var displayContent: String {
        let processedContent: String
        switch type {
        case .text:
            processedContent = content
        case .image:
            if let dimensions = imageDimensions, let size = imageSize {
                let sizeStr = formatBytes(size)
                processedContent = "Image (\(dimensions), \(sizeStr))"
            } else {
                processedContent = "Image (\(content))"
            }
        case .link:
            processedContent = content
        case .file:
            processedContent = "File: \(content)"
        case .code:
            processedContent = content
        }
        
        // Replace newlines with line break symbols (↵)
        return processedContent.replacingOccurrences(of: "\n", with: " ↵ ")
    }
    
    // \u683c\u5f0f\u5316\u5b57\u8282\u6570
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    var icon: String {
        switch type {
        case .text:
            return "doc.text"
        case .image:
            return "photo"
        case .link:
            return "link"
        case .file:
            return "doc"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    mutating func toggleFavorite() {
        isFavorite.toggle()
    }
}

enum ClipboardItemType: String, CaseIterable, Codable {
    case text = "Text"
    case image = "Image"
    case link = "Link"
    case file = "File"
    case code = "Code"
}

enum ClipboardCategory: String, CaseIterable {
    case history = "History"
    case favorites = "Favorites"
    case files = "Files"
    case images = "Images"
    case links = "Links"
    case code = "Code"
    case mail = "Mail"
    case chrome = "Chrome"
    
    var icon: String {
        switch self {
        case .history: return "clock"
        case .favorites: return "star"
        case .files: return "folder"
        case .images: return "photo"
        case .links: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .mail: return "envelope"
        case .chrome: return "globe"
        }
    }
}
