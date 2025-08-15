import Foundation
import SwiftUI

class LinkMetadataService: ObservableObject {
    static let shared = LinkMetadataService()
    
    private let urlSession: URLSession
    private let cache = NSCache<NSString, CachedPreviewData>()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        self.urlSession = URLSession(configuration: config)
        
        // 设置缓存限制
        cache.countLimit = 100
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
    
    func fetchMetadata(for urlString: String) async -> LinkPreviewData? {
        guard let url = URL(string: urlString) else { return nil }
        
        // 检查缓存
        let cacheKey = NSString(string: urlString)
        if let cached = cache.object(forKey: cacheKey) {
            if Date().timeIntervalSince(cached.timestamp) < 3600 { // 1小时缓存
                return cached.data
            } else {
                cache.removeObject(forKey: cacheKey)
            }
        }
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let htmlString = String(data: data, encoding: .utf8) ?? ""
            let metadata = parseHTMLMetadata(htmlString, url: url)
            
            // 缓存结果
            let cachedData = CachedPreviewData(data: metadata, timestamp: Date())
            cache.setObject(cachedData, forKey: cacheKey)
            
            return metadata
        } catch {
            print("Error fetching metadata for \(urlString): \(error)")
            return generateFallbackMetadata(for: url)
        }
    }
    
    private func parseHTMLMetadata(_ html: String, url: URL) -> LinkPreviewData {
        var title: String?
        var description: String?
        var iconURL: String?
        
        // 解析标题
        title = extractContent(from: html, pattern: #"<title[^>]*>(.*?)</title>"#)
            ?? extractMetaContent(from: html, property: "og:title")
            ?? extractMetaContent(from: html, name: "twitter:title")
        
        // 解析描述
        description = extractMetaContent(from: html, property: "og:description")
            ?? extractMetaContent(from: html, name: "twitter:description")  
            ?? extractMetaContent(from: html, name: "description")
        
        // 解析图标
        iconURL = extractMetaContent(from: html, property: "og:image")
            ?? extractMetaContent(from: html, name: "twitter:image")
            ?? extractLinkHref(from: html, rel: "icon")
            ?? extractLinkHref(from: html, rel: "shortcut icon")
            ?? extractLinkHref(from: html, rel: "apple-touch-icon")
        
        // 处理相对URL
        if let originalIconURL = iconURL, !originalIconURL.hasPrefix("http") {
            iconURL = resolveRelativeURL(originalIconURL, baseURL: url)
        }
        
        return LinkPreviewData(
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            domain: url.host,
            iconURL: iconURL
        )
    }
    
    private func extractContent(from html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: html.utf16.count)
        if let match = regex.firstMatch(in: html, options: [], range: range) {
            let matchRange = match.range(at: 1)
            if let swiftRange = Range(matchRange, in: html) {
                return String(html[swiftRange])
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#39;", with: "'")
            }
        }
        
        return nil
    }
    
    private func extractMetaContent(from html: String, property: String? = nil, name: String? = nil) -> String? {
        let attributeName = property != nil ? "property" : "name"
        let attributeValue = property ?? name ?? ""
        
        let pattern = #"<meta\s+[^>]*\#(attributeName)=["']?\#(attributeValue)["']?[^>]*content=["']([^"']*?)["'][^>]*>"#
        
        return extractContent(from: html, pattern: pattern)
    }
    
    private func extractLinkHref(from html: String, rel: String) -> String? {
        let pattern = #"<link\s+[^>]*rel=["']?\#(rel)["']?[^>]*href=["']([^"']*?)["'][^>]*>"#
        return extractContent(from: html, pattern: pattern)
    }
    
    private func resolveRelativeURL(_ relativePath: String, baseURL: URL) -> String {
        if relativePath.hasPrefix("//") {
            return (baseURL.scheme ?? "https") + ":" + relativePath
        } else if relativePath.hasPrefix("/") {
            return "\(baseURL.scheme ?? "https")://\(baseURL.host ?? "")\(relativePath)"
        } else {
            return "\(baseURL.scheme ?? "https")://\(baseURL.host ?? "")/\(relativePath)"
        }
    }
    
    private func generateFallbackMetadata(for url: URL) -> LinkPreviewData {
        let domain = url.host ?? "Unknown"
        let title = generateTitle(from: url)
        
        return LinkPreviewData(
            title: title,
            description: "Visit \(domain) for more information",
            domain: domain,
            iconURL: nil
        )
    }
    
    private func generateTitle(from url: URL) -> String {
        let host = url.host ?? "Website"
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        if let lastComponent = pathComponents.last {
            return lastComponent.replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        } else {
            return host.capitalized
        }
    }
}

// 缓存数据结构
private class CachedPreviewData {
    let data: LinkPreviewData
    let timestamp: Date
    
    init(data: LinkPreviewData, timestamp: Date) {
        self.data = data
        self.timestamp = timestamp
    }
}