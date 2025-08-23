import Foundation
import SwiftUI
import GRDB

struct ClipboardItem: Identifiable, Hashable, Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
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
        self.id = nil  // 将由数据库自动生成
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
            // Remove leading whitespace to avoid wasting visual space in list display
            var trimmedContent = content
            while trimmedContent.hasPrefix(" ") || trimmedContent.hasPrefix("\t") {
                trimmedContent = String(trimmedContent.dropFirst())
            }
            processedContent = trimmedContent
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

// MARK: - GRDB Extensions
extension ClipboardItem {
    // 定义数据库表名
    static let databaseTableName = "clipboard_items"
    
    // GRDB字段映射
    enum Columns {
        static let id = Column("id")
        static let content = Column("content")
        static let type = Column("type")
        static let timestamp = Column("timestamp")
        static let sourceApp = Column("source_app")
        static let sourceAppBundleID = Column("source_app_bundle_id")
        static let isFavorite = Column("is_favorite")
        static let htmlContent = Column("html_content")
        static let copyCount = Column("copy_count")
        static let firstCopyTime = Column("first_copy_time")
        static let lastCopyTime = Column("last_copy_time")
        static let imageData = Column("image_data")
        static let imageDimensions = Column("image_dimensions")
        static let imageSize = Column("image_size")
        static let filePath = Column("file_path")
    }
    
    // 自定义编码键以匹配数据库字段
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case type
        case timestamp
        case sourceApp = "source_app"
        case sourceAppBundleID = "source_app_bundle_id"
        case isFavorite = "is_favorite"
        case htmlContent = "html_content"
        case copyCount = "copy_count"
        case firstCopyTime = "first_copy_time"
        case lastCopyTime = "last_copy_time"
        case imageData = "image_data"
        case imageDimensions = "image_dimensions"
        case imageSize = "image_size"
        case filePath = "file_path"
    }
    
    // GRDB插入后更新ID
    mutating func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
    }
    
    // 时间戳编码/解码处理
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(Int64.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        type = try container.decode(ClipboardItemType.self, forKey: .type)
        sourceApp = try container.decode(String.self, forKey: .sourceApp)
        sourceAppBundleID = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        htmlContent = try container.decodeIfPresent(String.self, forKey: .htmlContent)
        copyCount = try container.decode(Int.self, forKey: .copyCount)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        imageDimensions = try container.decodeIfPresent(String.self, forKey: .imageDimensions)
        imageSize = try container.decodeIfPresent(Int64.self, forKey: .imageSize)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        
        // 处理时间戳字段（从毫秒转换为Date）
        let timestampMs = try container.decode(Int64.self, forKey: .timestamp)
        timestamp = Date(timeIntervalSince1970: Double(timestampMs) / 1000.0)
        
        let firstCopyTimeMs = try container.decode(Int64.self, forKey: .firstCopyTime)
        firstCopyTime = Date(timeIntervalSince1970: Double(firstCopyTimeMs) / 1000.0)
        
        let lastCopyTimeMs = try container.decode(Int64.self, forKey: .lastCopyTime)
        lastCopyTime = Date(timeIntervalSince1970: Double(lastCopyTimeMs) / 1000.0)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(type, forKey: .type)
        try container.encode(sourceApp, forKey: .sourceApp)
        try container.encodeIfPresent(sourceAppBundleID, forKey: .sourceAppBundleID)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(htmlContent, forKey: .htmlContent)
        try container.encode(copyCount, forKey: .copyCount)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encodeIfPresent(imageDimensions, forKey: .imageDimensions)
        try container.encodeIfPresent(imageSize, forKey: .imageSize)
        try container.encodeIfPresent(filePath, forKey: .filePath)
        
        // 将Date转换为毫秒时间戳
        try container.encode(Int64(timestamp.timeIntervalSince1970 * 1000), forKey: .timestamp)
        try container.encode(Int64(firstCopyTime.timeIntervalSince1970 * 1000), forKey: .firstCopyTime)
        try container.encode(Int64(lastCopyTime.timeIntervalSince1970 * 1000), forKey: .lastCopyTime)
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
