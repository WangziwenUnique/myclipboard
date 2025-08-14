import Foundation
import SwiftUI
import AppKit
import CryptoKit

class ClipboardManager: ObservableObject {
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var selectedItem: ClipboardItem?
    
    private var timer: Timer?
    private var lastClipboardContent: String = ""
    private var lastClipboardChangeCount: Int = 0
    private let dataManager = ClipboardDataManager()
    private let maxItems = 1000  // 增加存储上限
    
    // 数据存储配置
    private let maxContentSize = 1024 * 1024  // 1MB 最大内容大小
    private let excludedApps = ["Keychain Access", "1Password"]  // 排除的应用
    
    init() {
        loadPersistedData()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        // 初始化剪贴板状态
        lastClipboardChangeCount = NSPasteboard.general.changeCount
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            self.checkClipboard()
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        // 只有在剪贴板真正变化时才处理
        guard currentChangeCount != lastClipboardChangeCount else { return }
        lastClipboardChangeCount = currentChangeCount
        
        // 检查多种数据类型
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // 检查内容大小限制
            guard string.utf8.count <= maxContentSize else {
                print("内容太大，跳过: \(string.utf8.count) bytes")
                return
            }
            
            // 检查是否为重复内容
            if string != lastClipboardContent {
                lastClipboardContent = string
                addClipboardItem(content: string, pasteboard: pasteboard)
            }
        } else if let imageData = pasteboard.data(forType: .tiff) {
            // 处理图片
            handleImageData(imageData, from: pasteboard)
        } else if let imageData = pasteboard.data(forType: .png) {
            // 处理 PNG 图片
            handleImageData(imageData, from: pasteboard)
        } else if let fileURLs = pasteboard.propertyList(forType: .fileURL) as? [String] {
            // 处理文件
            let filesInfo = fileURLs.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
            addClipboardItem(content: "Files: \(filesInfo)", type: .file, pasteboard: pasteboard)
        }
    }
    
    private func handleImageData(_ imageData: Data, from pasteboard: NSPasteboard) {
        // 检查图片大小限制（最大 20MB）- 使用内存中的位图大小防止内存溢出
        let maxImageSize = 20 * 1024 * 1024
        guard imageData.count <= maxImageSize else {
            print("图片太大，跳过: \(formatBytes(imageData.count))")
            return
        }
        
        // 获取图片尺寸信息
        var dimensions = "Unknown"
        
        // 尝试获取真实的文件大小（用于显示）
        let displaySize = getRealImageSize(imageData: imageData, pasteboard: pasteboard)
        
        if let nsImage = NSImage(data: imageData) {
            let size = nsImage.size
            dimensions = "\(Int(size.width))x\(Int(size.height))"
        }
        
        let sourceApp = getCurrentSourceApp()
        
        // 检查是否从排除的应用复制
        if excludedApps.contains(sourceApp) {
            print("跳过排除应用: \(sourceApp)")
            return
        }
        
        let newItem = ClipboardItem(
            content: "Screenshot", // 简化的内容描述
            type: .image,
            sourceApp: sourceApp,
            htmlContent: getHTMLContent(from: pasteboard),
            imageData: imageData,
            imageDimensions: dimensions,
            imageSize: displaySize
        )
        
        DispatchQueue.main.async {
            // 检查重复项（基于图片数据哈希）
            let imageHash = imageData.sha256
            if !self.clipboardItems.contains(where: { 
                $0.type == .image && $0.imageData?.sha256 == imageHash 
            }) {
                self.clipboardItems.insert(newItem, at: 0)
                
                // 限制数量
                if self.clipboardItems.count > self.maxItems {
                    self.clipboardItems = Array(self.clipboardItems.prefix(self.maxItems))
                }
                
                // 保存到本地
                self.saveDataAsync()
            }
        }
    }
    
    private func addClipboardItem(content: String, type: ClipboardItemType = .text, pasteboard: NSPasteboard) {
        let actualType = type == .text ? determineType(from: content) : type
        let sourceApp = getCurrentSourceApp()
        let htmlContent = getHTMLContent(from: pasteboard)
        
        // 检查是否从排除的应用复制
        if excludedApps.contains(sourceApp) {
            print("跳过排除应用: \(sourceApp)")
            return
        }
        
        let newItem = ClipboardItem(
            content: content,
            type: actualType,
            sourceApp: sourceApp,
            htmlContent: htmlContent
        )
        
        DispatchQueue.main.async {
            // 检查重复项
            if !self.clipboardItems.contains(where: { $0.content == content }) {
                self.clipboardItems.insert(newItem, at: 0)
                
                // 限制数量
                if self.clipboardItems.count > self.maxItems {
                    self.clipboardItems = Array(self.clipboardItems.prefix(self.maxItems))
                }
                
                // 保存到本地
                self.saveDataAsync()
            }
        }
    }
    
    private func determineType(from content: String) -> ClipboardItemType {
        if content.hasPrefix("http://") || content.hasPrefix("https://") {
            return .link
        } else if content.contains("```") || content.contains("import ") || content.contains("function ") {
            return .code
        } else {
            return .text
        }
    }
    
    // 尝试获取图片的真实文件大小（用于显示）
    private func getRealImageSize(imageData: Data, pasteboard: NSPasteboard) -> Int64 {
        // 方法1: 尝试从剪贴板获取文件URL
        if let fileURL = getFileURLFromPasteboard(pasteboard: pasteboard) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[.size] as? Int64 {
                    return fileSize
                }
            } catch {
                // 文件访问失败，继续尝试其他方法
            }
        }
        
        // 方法2: 尝试将图片重新编码为JPEG估算压缩后大小
        if let nsImage = NSImage(data: imageData),
           let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                return Int64(jpegData.count)
            }
        }
        
        // 方法3: 后备方案 - 返回内存中的位图大小
        return Int64(imageData.count)
    }
    
    // 尝试从剪贴板获取文件URL
    private func getFileURLFromPasteboard(pasteboard: NSPasteboard) -> URL? {
        // 检查是否有文件URL类型
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if url.isFileURL {
                    let pathExtension = url.pathExtension.lowercased()
                    // 检查是否是图片文件
                    if ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"].contains(pathExtension) {
                        return url
                    }
                }
            }
        }
        return nil
    }
    
    private func getCurrentSourceApp() -> String {
        // 获取当前活跃应用
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            return frontmostApp.localizedName ?? "Unknown"
        }
        return "Unknown"
    }
    
    private func getHTMLContent(from pasteboard: NSPasteboard) -> String? {
        return pasteboard.string(forType: .html)
    }
    
    // 格式化字节数
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    func copyToClipboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }
    
    func copyImageToClipboard(_ imageData: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(imageData, forType: .tiff)
    }
    
    func toggleFavorite(for item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = item
            updatedItem.toggleFavorite()
            clipboardItems[index] = updatedItem
            saveDataAsync()
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        clipboardItems.removeAll { $0.id == item.id }
        if selectedItem?.id == item.id {
            selectedItem = clipboardItems.first
        }
        saveDataAsync()
    }
    
    func searchItems(query: String) -> [ClipboardItem] {
        if query.isEmpty {
            return clipboardItems
        }
        return clipboardItems.filter { item in
            item.content.localizedCaseInsensitiveContains(query) ||
            item.sourceApp.localizedCaseInsensitiveContains(query)
        }
    }
    
    func getItemsByCategory(_ category: ClipboardCategory) -> [ClipboardItem] {
        switch category {
        case .history:
            return clipboardItems
        case .favorites:
            return clipboardItems.filter { $0.isFavorite }
        case .files:
            return clipboardItems.filter { $0.type == .file }
        case .images:
            return clipboardItems.filter { $0.type == .image }
        case .links:
            return clipboardItems.filter { $0.type == .link }
        case .code:
            return clipboardItems.filter { $0.type == .text && $0.content.contains("```") }
        case .mail:
            return clipboardItems.filter { $0.content.contains("@") && $0.content.contains(".") }
        case .chrome:
            return clipboardItems.filter { $0.sourceApp == "Google Chrome" }
        }
    }
    
    func getSortedItems(for category: ClipboardCategory, sortOption: SortOption, isReversed: Bool = false) -> [ClipboardItem] {
        let items = getItemsByCategory(category)
        let sortedItems: [ClipboardItem]
        
        switch sortOption {
        case .lastCopyTime:
            sortedItems = items.sorted { $0.timestamp > $1.timestamp }
        case .firstCopyTime:
            sortedItems = items.sorted { $0.timestamp < $1.timestamp }
        case .numberOfCopies:
            // For numberOfCopies, we'll use a simple heuristic based on content similarity
            // In a real implementation, you'd track actual copy counts
            sortedItems = items.sorted { item1, item2 in
                let count1 = items.filter { $0.content.prefix(50) == item1.content.prefix(50) }.count
                let count2 = items.filter { $0.content.prefix(50) == item2.content.prefix(50) }.count
                return count1 > count2
            }
        case .size:
            sortedItems = items.sorted { $0.content.count > $1.content.count }
        }
        
        return isReversed ? sortedItems.reversed() : sortedItems
    }
    
    // MARK: - Data Persistence
    
    private func loadPersistedData() {
        do {
            let items = try dataManager.loadItems()
            DispatchQueue.main.async {
                self.clipboardItems = items
                self.selectedItem = items.first
            }
            print("已加载 \(items.count) 个剪贴板项目")
        } catch {
            print("加载数据失败: \(error)")
            // 如果加载失败，可以选择加载示例数据用于测试
            // loadSampleData()
        }
    }
    
    private func saveDataAsync() {
        // 在后台线程执行保存操作，避免阻塞UI
        Task.detached { [weak self] in
            guard let self = self else { return }
            do {
                try await self.dataManager.saveItems(self.clipboardItems)
            } catch {
                print("保存数据失败: \(error)")
            }
        }
    }
    
    // 清理旧数据（可以定期调用）
    func cleanupOldData() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let filteredItems = clipboardItems.filter { $0.timestamp > thirtyDaysAgo || $0.isFavorite }
        
        if filteredItems.count != clipboardItems.count {
            clipboardItems = filteredItems
            saveDataAsync()
            print("已清理 \(clipboardItems.count - filteredItems.count) 个过期项目")
        }
    }
    
    private func loadSampleData() {
        let sampleItems = [
            ClipboardItem(content: "LAIS-9074-5758-1212-0858427276105608", sourceApp: "Xcode"),
            ClipboardItem(content: """
{
    "l1": {
        "l1_1": [
            "l1_1_1",
            "l1_1_2"
        ],
        "l1_2": {
            "l1_2_1": 121
        }
    },
    "l2": {
        "l2_1": null,
        "l2_2": true,
        "l2_3": {}
    }
}
""", sourceApp: "Xcode"),
            ClipboardItem(content: "https://myclipboard.org/", type: .link, sourceApp: "Safari"),
            ClipboardItem(content: "Feature:", sourceApp: "Xcode"),
            ClipboardItem(content: "相似问检索...", sourceApp: "Notes"),
            ClipboardItem(content: "大模型【通话内容】...", sourceApp: "Notes"),
            ClipboardItem(content: "Image (3478x1242)", type: .image, sourceApp: "Preview"),
            ClipboardItem(content: "https://myclipboard.org/sitemap.xml", type: .link, sourceApp: "Safari"),
            ClipboardItem(content: "google-site-verification=19Ft96zVfubt38LxWx5l...", sourceApp: "Safari"),
            ClipboardItem(content: "google-site-verification", sourceApp: "Safari"),
            ClipboardItem(content: "https://byaitech.feishu.cn/docx/Xfbjd2a0douCF9...", type: .link, sourceApp: "Safari"),
            ClipboardItem(content: "https://byaitech.feishu.cn/wiki/N47qwKJq8isqAc...", type: .link, sourceApp: "Safari")
        ]
        
        clipboardItems = sampleItems
        selectedItem = sampleItems.first
    }
}

// MARK: - Data Extensions
extension Data {
    var sha256: String {
        let hashed = SHA256.hash(data: self)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
