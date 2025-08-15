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
    
    // 复制统计相关
    var copyCount: Int
    let firstCopyTime: Date
    var lastCopyTime: Date
    
    // 应用图标相关
    let sourceAppBundleID: String?
    
    // 图片相关数据
    let imageData: Data?        // Base64 编码的图片数据
    let imageDimensions: String? // 图片尺寸信息
    let imageSize: Int64?       // 图片文件大小
    let filePath: String?       // 文件路径（用于本地文件）
    
    // 文本相关属性
    var characterCount: Int? {
        guard type == .text else { return nil }
        return content.count
    }
    
    var lineCount: Int? {
        guard type == .text else { return nil }
        return content.components(separatedBy: .newlines).count
    }
    
    var contentSize: Int64? {
        guard type == .text else { return nil }
        return Int64(content.utf8.count)
    }
    
    // 链接相关属性
    var urlComponents: URLComponents? {
        guard type == .link, let url = URL(string: content) else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)
    }
    
    var domain: String? {
        return urlComponents?.host
    }
    
    var urlProtocol: String? {
        return urlComponents?.scheme
    }
    
    // 文件相关属性
    var fileExtension: String? {
        guard type == .file else { return nil }
        return (content as NSString).pathExtension
    }
    
    // 邮箱相关属性
    var emailDomain: String? {
        guard type == .email else { return nil }
        let emailPattern = #"[A-Z0-9._%+-]+@([A-Z0-9.-]+\.[A-Z]{2,})"#
        let regex = try? NSRegularExpression(pattern: emailPattern, options: [.caseInsensitive])
        let range = NSRange(location: 0, length: content.utf16.count)
        
        if let match = regex?.firstMatch(in: content, options: [], range: range) {
            let domainRange = match.range(at: 1)
            if let swiftRange = Range(domainRange, in: content) {
                return String(content[swiftRange])
            }
        }
        return nil
    }
    
    init(content: String, type: ClipboardItemType = .text, sourceApp: String = "Unknown", htmlContent: String? = nil, isFavorite: Bool = false, imageData: Data? = nil, imageDimensions: String? = nil, imageSize: Int64? = nil, filePath: String? = nil, sourceAppBundleID: String? = nil) {
        self.id = UUID()
        self.content = content
        self.type = type
        let now = Date()
        self.timestamp = now
        self.firstCopyTime = now
        self.lastCopyTime = now
        self.copyCount = 1
        self.sourceApp = sourceApp
        self.sourceAppBundleID = sourceAppBundleID
        self.isFavorite = isFavorite
        self.htmlContent = htmlContent
        self.imageData = imageData
        self.imageDimensions = imageDimensions
        self.imageSize = imageSize
        self.filePath = filePath
    }
    
    mutating func incrementCopyCount() {
        self.copyCount += 1
        self.lastCopyTime = Date()
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
        case .email:
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
        case .email:
            return "envelope"
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
    case email = "Email"
}

enum ClipboardCategory: String, CaseIterable {
    case history = "History"
    case favorites = "Favorites"
    case text = "Text"
    case images = "Images"
    case links = "Links"
    case files = "Files"
    case mail = "Mail"
    
    var icon: String {
        switch self {
        case .history: return "clock"
        case .favorites: return "star"
        case .text: return "doc.text"
        case .images: return "photo"
        case .links: return "link"
        case .files: return "folder"
        case .mail: return "envelope"
        }
    }
}
