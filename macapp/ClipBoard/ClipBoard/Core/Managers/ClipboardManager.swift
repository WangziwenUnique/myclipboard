import Foundation
import SwiftUI
import AppKit
import CryptoKit

class ClipboardManager: NSObject, ObservableObject {
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var selectedItem: ClipboardItem?
    @Published var isMonitoring: Bool = true
    
    private var lastClipboardContent: String = ""
    private let repository: ClipboardRepository = SQLiteClipboardRepository()
    private let maxItems = 1000  // 增加存储上限
    
    // 分页参数
    private let pageSize = 100
    private var currentPage = 0
    private var isLoading = false
    private var hasMoreData = true
    
    // Timer轮询监控
    private var clipboardTimer: Timer?
    private var lastChangeCount: Int = 0
    
    // SQLite优化：单项保存（无需批量操作）
    
    // 数据存储配置
    private let maxContentSize = 1024 * 1024  // 1MB 最大内容大小
    private let excludedApps = ["Keychain Access", "1Password"]  // 排除的应用
    
    override init() {
        super.init()
        
        // 从 UserDefaults 加载监控状态
        isMonitoring = UserDefaults.standard.object(forKey: "clipboardMonitoring") == nil ? true : UserDefaults.standard.bool(forKey: "clipboardMonitoring")
        
        loadPersistedData()
        startTimerMonitoring()
    }
    
    deinit {
        stopTimerMonitoring()
    }
    
    private func startTimerMonitoring() {
        // 初始化剪贴板状态
        lastChangeCount = NSPasteboard.general.changeCount
        
        // 使用Timer轮询监控剪贴板变化（业界标准做法）
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkClipboardChanges()
            }
        }
        
        print("✅ 剪贴板监控已启动 (Timer轮询)")
    }
    
    private func stopTimerMonitoring() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        print("🛑 剪贴板监控已停止")
    }
    
    private func checkClipboardChanges() {
        let currentChangeCount = NSPasteboard.general.changeCount
        
        // 只有在changeCount真正变化时才处理
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            checkClipboard()
        }
    }
    
    private func checkClipboard() {
        // 如果监控被暂停，直接返回
        guard isMonitoring else { return }
        
        let pasteboard = NSPasteboard.general
        
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
        let sourceAppBundleID = getCurrentSourceAppBundleID()
        
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
            imageSize: displaySize,
            sourceAppBundleID: sourceAppBundleID
        )
        
        DispatchQueue.main.async {
            // 检查重复项（基于图片数据哈希）
            let imageHash = imageData.sha256
            if let existingIndex = self.clipboardItems.firstIndex(where: { 
                $0.type == .image && $0.imageData?.sha256 == imageHash 
            }) {
                // 找到重复项，增加复制次数并移到顶部
                var existingItem = self.clipboardItems[existingIndex]
                existingItem.incrementCopyCount()
                self.clipboardItems.remove(at: existingIndex)
                self.clipboardItems.insert(existingItem, at: 0)
                
                // 保存到数据库
                self.saveItem(existingItem)
            } else {
                // 新项目，添加到列表和数据库
                self.clipboardItems.insert(newItem, at: 0)
                
                // 限制数量
                if self.clipboardItems.count > self.maxItems {
                    self.clipboardItems = Array(self.clipboardItems.prefix(self.maxItems))
                }
                
                // 保存到数据库
                self.saveItem(newItem)
            }
        }
    }
    
    private func addClipboardItem(content: String, type: ClipboardItemType = .text, pasteboard: NSPasteboard) {
        let actualType = type == .text ? determineType(from: content) : type
        let sourceApp = getCurrentSourceApp()
        let sourceAppBundleID = getCurrentSourceAppBundleID()
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
            htmlContent: htmlContent,
            sourceAppBundleID: sourceAppBundleID
        )
        
        DispatchQueue.main.async {
            // 检查重复项
            if let existingIndex = self.clipboardItems.firstIndex(where: { $0.content == content }) {
                // 找到重复项，增加复制次数并移到顶部
                var existingItem = self.clipboardItems[existingIndex]
                existingItem.incrementCopyCount()
                self.clipboardItems.remove(at: existingIndex)
                self.clipboardItems.insert(existingItem, at: 0)
                
                // 保存到数据库
                self.saveItem(existingItem)
            } else {
                // 新项目，添加到列表和数据库
                self.clipboardItems.insert(newItem, at: 0)
                
                // 限制数量
                if self.clipboardItems.count > self.maxItems {
                    self.clipboardItems = Array(self.clipboardItems.prefix(self.maxItems))
                }
                
                // 保存到数据库
                self.saveItem(newItem)
            }
        }
    }
    
    private func determineType(from content: String) -> ClipboardItemType {
        if content.hasPrefix("http://") || content.hasPrefix("https://") {
            return .link
        } else if isValidEmail(content.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return .email
        } else {
            return .text
        }
    }
    
    // 精确的邮箱检测方法
    private func isValidEmail(_ content: String) -> Bool {
        let emailPattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let regex = try? NSRegularExpression(pattern: emailPattern, options: [.caseInsensitive])
        let range = NSRange(location: 0, length: content.utf16.count)
        return regex?.firstMatch(in: content, options: [], range: range) != nil
    }
    
    // 获取图片的估算文件大小（用于显示）
    private func getRealImageSize(imageData: Data, pasteboard: NSPasteboard) -> Int64 {
        // 方法1: 尝试从剪贴板获取文件URL（文件复制的情况）
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
        
        // 方法2: 判断是否为截图，如果是则估算压缩后的文件大小
        if isLikelyScreenshot(pasteboard: pasteboard, imageData: imageData) {
            return estimateCompressedImageSize(imageData: imageData)
        }
        
        // 方法3: 其他情况 - 使用适度的压缩估算
        return estimateCompressedImageSize(imageData: imageData, useHigherCompression: false)
    }
    
    // 判断是否可能是截图
    private func isLikelyScreenshot(pasteboard: NSPasteboard, imageData: Data) -> Bool {
        // 检查1: 来源应用是否为截图相关
        let sourceApp = getCurrentSourceApp()
        let screenshotApps = ["System UI Server", "Screenshot", "CleanShot X", "System Preferences", "Finder"]
        if screenshotApps.contains(sourceApp) {
            return true
        }
        
        // 检查2: 数据大小特征（截图通常在剪贴板中是未压缩的，会比较大）
        let dataSizeKB = imageData.count / 1024
        if dataSizeKB > 500 { // 大于500KB可能是未压缩的截图
            // 检查3: 是否有文件URL，如果没有且数据很大，很可能是截图
            if getFileURLFromPasteboard(pasteboard: pasteboard) == nil {
                return true
            }
        }
        
        return false
    }
    
    // 精确估算压缩后的图片文件大小（复现macOS保存流程）
    private func estimateCompressedImageSize(imageData: Data, useHigherCompression: Bool = true) -> Int64 {
        guard let nsImage = NSImage(data: imageData),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            // 如果无法解析图片，返回原始数据大小的一个合理比例
            return Int64(Double(imageData.count) * 0.1)
        }
        
        // 对截图使用精确的PNG压缩（复现系统保存）
        if useHigherCompression {
            if let accuratePngSize = estimateSystemLikePngSize(cgImage: cgImage) {
                return accuratePngSize
            }
        }
        
        // 备用方案：使用JPEG压缩估算
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let compressionFactor: Float = useHigherCompression ? 0.7 : 0.8
        if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor]) {
            return Int64(jpegData.count)
        }
        
        // 最后的备用方案：基于经验的估算
        return Int64(Double(imageData.count) * 0.1)
    }
    
    // 精确复现macOS系统PNG保存的大小估算
    private func estimateSystemLikePngSize(cgImage: CGImage) -> Int64? {
        // 创建正确配置的NSBitmapImageRep
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        
        // 配置PNG属性，复现系统保存参数
        let pngProperties: [NSBitmapImageRep.PropertyKey: Any] = [
            // PNG interlacing（系统通常禁用以减小文件大小）
            .interlaced: false
        ]
        
        // 生成PNG数据
        if let pngData = bitmapRep.representation(using: .png, properties: pngProperties) {
            var estimatedSize = Int64(pngData.count)
            
            // 添加系统PNG元数据的估算大小
            estimatedSize += estimatePngMetadataSize(width: cgImage.width, height: cgImage.height)
            
            return estimatedSize
        }
        
        return nil
    }
    
    // 估算PNG元数据大小（时间戳、软件信息等）
    private func estimatePngMetadataSize(width: Int, height: Int) -> Int64 {
        var metadataSize: Int64 = 0
        
        // sRGB颜色配置文件 chunk
        metadataSize += 3144 // 标准sRGB配置文件大小
        
        // tEXt chunks（文本元数据）
        metadataSize += 50   // 创建时间
        metadataSize += 30   // 软件信息
        metadataSize += 20   // 其他标准元数据
        
        // pHYs chunk（物理像素尺寸）
        metadataSize += 21
        
        // bKGD chunk（背景色，如果有的话）
        metadataSize += 15
        
        // chunk头部开销
        metadataSize += 80   // 各种chunk的头部和CRC
        
        return metadataSize
    }
    
    // 尝试从剪贴板获取文件URL
    private func getFileURLFromPasteboard(pasteboard: NSPasteboard) -> URL? {
        // 方法1: 检查文件URL类型
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if url.isFileURL {
                    let pathExtension = url.pathExtension.lowercased()
                    // 检查是否是图片文件
                    if ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "heif"].contains(pathExtension) {
                        return url
                    }
                }
            }
        }
        
        // 方法2: 检查文件URL字符串类型
        if let fileURLs = pasteboard.propertyList(forType: .fileURL) as? [String] {
            for urlString in fileURLs {
                if let url = URL(string: urlString), url.isFileURL {
                    let pathExtension = url.pathExtension.lowercased()
                    if ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "heif"].contains(pathExtension) {
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
    
    private func getCurrentSourceAppBundleID() -> String? {
        // 获取当前活跃应用的 Bundle ID
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            return frontmostApp.bundleIdentifier
        }
        return nil
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
            saveItem(updatedItem)
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        clipboardItems.removeAll { $0.id == item.id }
        if selectedItem?.id == item.id {
            selectedItem = clipboardItems.first
        }
        Task {
            do {
                try await repository.delete(item.id)
            } catch {
                print("删除项目失败: \(error)")
            }
        }
    }
    
    func searchItems(query: String) -> [ClipboardItem] {
        if query.isEmpty {
            return clipboardItems
        }
        // 暂时保持内存搜索，可以后续优化为数据库搜索
        return clipboardItems.filter { item in
            item.content.localizedCaseInsensitiveContains(query) ||
            item.sourceApp.localizedCaseInsensitiveContains(query)
        }
    }
    
    func getItemsByCategory(_ category: ClipboardCategory) -> [ClipboardItem] {
        // 暂时保持内存过滤，因为UI层仍在使用同步方法
        switch category {
        case .history:
            return clipboardItems
        case .favorites:
            return clipboardItems.filter { $0.isFavorite }
        case .text:
            return clipboardItems.filter { $0.type == .text }
        case .files:
            return clipboardItems.filter { $0.type == .file }
        case .images:
            return clipboardItems.filter { $0.type == .image }
        case .links:
            return clipboardItems.filter { $0.type == .link }
        case .mail:
            return clipboardItems.filter { $0.type == .email }
        }
    }
    
    func getSortedItems(for category: ClipboardCategory, sortOption: SortOption, isReversed: Bool = false) -> [ClipboardItem] {
        let items = getItemsByCategory(category)
        let sortedItems: [ClipboardItem]
        
        switch sortOption {
        case .lastCopyTime:
            sortedItems = items.sorted { $0.lastCopyTime > $1.lastCopyTime }
        case .firstCopyTime:
            sortedItems = items.sorted { $0.firstCopyTime < $1.firstCopyTime }
        case .numberOfCopies:
            sortedItems = items.sorted { $0.copyCount > $1.copyCount }
        case .size:
            sortedItems = items.sorted { $0.content.count > $1.content.count }
        }
        
        return isReversed ? sortedItems.reversed() : sortedItems
    }
    
    // MARK: - Data Persistence
    
    private func loadPersistedData() {
        Task {
            await loadPage(0)
        }
    }
    
    private func loadPage(_ page: Int) async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            let items = try await repository.loadPage(page: page, limit: pageSize)
            await MainActor.run {
                if page == 0 {
                    self.clipboardItems = items
                    self.selectedItem = items.first
                } else {
                    self.clipboardItems.append(contentsOf: items)
                }
                self.hasMoreData = items.count == self.pageSize
                self.currentPage = page
            }
            print("已加载第\(page)页，共 \(items.count) 个剪贴板项目")
        } catch {
            print("加载第\(page)页失败: \(error)")
        }
        
        isLoading = false
    }
    
    func loadMoreIfNeeded() {
        guard !isLoading && hasMoreData else { return }
        let nextPage = currentPage + 1
        Task {
            await loadPage(nextPage)
        }
    }
    
    private func saveItem(_ item: ClipboardItem) {
        Task {
            do {
                let savedItem = try await repository.save(item)
                // 如果是新item（ID为0），需要更新内存中的item为带有正确ID的版本
                if item.id == 0 {
                    await MainActor.run {
                        if let index = self.clipboardItems.firstIndex(where: { $0.id == 0 }) {
                            self.clipboardItems[index] = savedItem
                        }
                    }
                }
            } catch {
                print("保存项目失败: \(error)")
            }
        }
    }
    
    private func saveDataAsync() {
        // SQLite版本中，单个项目保存已经在添加时完成
        // 这个方法保留用于兼容性，但不执行任何操作
    }
    
    // 清理旧数据（可以定期调用）
    func cleanupOldData() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        Task {
            do {
                try await repository.cleanupOldData(olderThan: thirtyDaysAgo)
                // 重新加载数据以更新内存中的列表
                let items = try await repository.loadAll()
                await MainActor.run {
                    self.clipboardItems = items
                    self.selectedItem = self.clipboardItems.first
                }
                print("已清理旧数据")
            } catch {
                print("清理数据失败: \(error)")
            }
        }
    }
    
    // MARK: - 监控控制
    
    func toggleMonitoring() {
        isMonitoring.toggle()
        print("\(isMonitoring ? "✅ 剪贴板监控已恢复" : "⏸️ 剪贴板监控已暂停")")
        
        // 保存监控状态到 UserDefaults
        UserDefaults.standard.set(isMonitoring, forKey: "clipboardMonitoring")
    }
    
    func pauseMonitoring() {
        if isMonitoring {
            isMonitoring = false
            print("⏸️ 剪贴板监控已暂停")
            UserDefaults.standard.set(false, forKey: "clipboardMonitoring")
        }
    }
    
    func resumeMonitoring() {
        if !isMonitoring {
            isMonitoring = true
            print("✅ 剪贴板监控已恢复")
            UserDefaults.standard.set(true, forKey: "clipboardMonitoring")
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
