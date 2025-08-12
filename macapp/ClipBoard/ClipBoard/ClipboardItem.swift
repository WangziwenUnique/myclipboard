import Foundation
import SwiftUI

struct ClipboardItem: Identifiable, Hashable {
    let id = UUID()
    let content: String
    let type: ClipboardItemType
    let timestamp: Date
    let sourceApp: String
    var isFavorite: Bool
    let htmlContent: String?
    
    init(content: String, type: ClipboardItemType = .text, sourceApp: String = "Unknown", htmlContent: String? = nil, isFavorite: Bool = false) {
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.sourceApp = sourceApp
        self.isFavorite = isFavorite
        self.htmlContent = htmlContent
    }
    
    var displayContent: String {
        switch type {
        case .text:
            return content
        case .image:
            return "Image (\(content))"
        case .link:
            return content
        case .file:
            return "File: \(content)"
        case .code:
            return content
        }
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

enum ClipboardItemType: String, CaseIterable {
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
