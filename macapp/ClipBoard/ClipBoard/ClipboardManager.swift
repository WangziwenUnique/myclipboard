import Foundation
import SwiftUI
import AppKit

class ClipboardManager: ObservableObject {
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var selectedItem: ClipboardItem?
    
    private var timer: Timer?
    private var lastClipboardContent: String = ""
    
    init() {
        startMonitoring()
        loadSampleData()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.checkClipboard()
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            if string != lastClipboardContent {
                lastClipboardContent = string
                addClipboardItem(content: string)
            }
        }
    }
    
    private func addClipboardItem(content: String) {
        let type = determineType(from: content)
        let sourceApp = getCurrentSourceApp()
        let htmlContent = getHTMLContent()
        
        let newItem = ClipboardItem(
            content: content,
            type: type,
            sourceApp: sourceApp,
            htmlContent: htmlContent
        )
        
        DispatchQueue.main.async {
            self.clipboardItems.insert(newItem, at: 0)
            if self.clipboardItems.count > 100 {
                self.clipboardItems = Array(self.clipboardItems.prefix(100))
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
    
    private func getCurrentSourceApp() -> String {
        // 简化实现，实际应用中需要获取真实的应用名称
        return "Xcode"
    }
    
    private func getHTMLContent() -> String? {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .html)
    }
    
    func copyToClipboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }
    
    func toggleFavorite(for item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = item
            updatedItem.toggleFavorite()
            clipboardItems[index] = updatedItem
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        clipboardItems.removeAll { $0.id == item.id }
        if selectedItem?.id == item.id {
            selectedItem = clipboardItems.first
        }
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
    
    private func loadSampleData() {
        let sampleItems = [
            ClipboardItem(content: "LAIS-9074-5758-1212-0858427276105608", sourceApp: "Xcode"),
            ClipboardItem(content: "SwiftUI", sourceApp: "Xcode"),
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
