import Foundation
import SwiftUI
import AppKit

// 统一的输入和选择管理器 - 合并KeyboardNavigationManager和SelectionManager
@MainActor
final class InputManager: ObservableObject {
    private let clipboardManager: ClipboardManager
    private let shortcutManager: KeyboardShortcutManager
    
    // Selection state - 原SelectionManager功能
    @Published private var selectedIndex: Int = 0
    private var items: [ClipboardItem] = []
    
    // Input state - 原KeyboardNavigationManager功能
    @Published var searchText: String = ""
    @Published var isSearchFocused: Bool = false
    
    private var observers: [NSObjectProtocol] = []
    
    init(clipboardManager: ClipboardManager, 
         shortcutManager: KeyboardShortcutManager) {
        self.clipboardManager = clipboardManager
        self.shortcutManager = shortcutManager
    }
    
    deinit {
        // 同步清理观察者，避免actor隔离问题
        let count = observers.count
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        if count > 0 {
            print("🧹 InputManager deinit - 清理了 \(count) 个观察者")
        }
    }
    
    // MARK: - Selection Management
    
    var selectedItem: ClipboardItem? {
        guard selectedIndex >= 0 && selectedIndex < items.count else { return nil }
        return items[selectedIndex]
    }
    
    var currentIndex: Int {
        selectedIndex
    }
    
    var isEmpty: Bool {
        items.isEmpty
    }
    
    var count: Int {
        items.count
    }
    
    func updateItems(_ newItems: [ClipboardItem]) {
        items = newItems
        
        // 自动修正无效的选择索引
        if selectedIndex >= items.count {
            selectedIndex = max(0, items.count - 1)
        }
    }
    
    func select(index: Int) {
        guard index >= 0 && index < items.count else { return }
        selectedIndex = index
    }
    
    func select(item: ClipboardItem) {
        if let index = items.firstIndex(of: item) {
            selectedIndex = index
        }
    }
    
    // MARK: - Navigation
    
    func navigateUp() {
        guard !isEmpty else { return }
        selectedIndex = max(0, selectedIndex - 1)
    }
    
    func navigateDown() {
        guard !isEmpty else { return }
        selectedIndex = min(items.count - 1, selectedIndex + 1)
    }
    
    func jumpToTop() {
        guard !isEmpty else { return }
        selectedIndex = 0
    }
    
    func jumpToBottom() {
        guard !isEmpty else { return }
        selectedIndex = items.count - 1
    }
    
    func selectByNumber(_ number: Int) -> Bool {
        let index = number - 1
        guard index >= 0 && index < items.count else { return false }
        selectedIndex = index
        return true
    }
    
    func reset() {
        selectedIndex = 0
    }
    
    func handleItemDeletion() {
        if selectedIndex >= items.count && !items.isEmpty {
            selectedIndex = items.count - 1
        } else if items.isEmpty {
            selectedIndex = 0
        }
    }
    
    // MARK: - Setup and Cleanup
    
    func setup() {
        cleanupObservers()
        setupShortcutHandlers()
        setupNotificationObservers()
    }
    
    func cleanup() {
        cleanupObservers()
    }
    
    // MARK: - Private Methods
    
    private func setupShortcutHandlers() {
        shortcutManager.registerHandler(for: .navigateUp) { [weak self] in
            self?.navigateUp()
        }
        
        shortcutManager.registerHandler(for: .navigateDown) { [weak self] in
            self?.navigateDown()
        }
        
        shortcutManager.registerHandler(for: .selectItem) { [weak self] in
            self?.selectCurrentItem()
        }
        
        shortcutManager.registerHandler(for: .jumpToTop) { [weak self] in
            self?.jumpToTop()
        }
        
        shortcutManager.registerHandler(for: .jumpToBottom) { [weak self] in
            self?.jumpToBottom()
        }
        
        // 数字键快速选择
        for i in 1...9 {
            let shortcut = KeyboardShortcutAction.fromNumber(i)
            shortcutManager.registerHandler(for: shortcut) { [weak self] in
                _ = self?.selectByNumber(i)
            }
        }
        
        // 搜索快捷键
        shortcutManager.registerHandler(for: .focusSearch) { [weak self] in
            self?.isSearchFocused = true
        }
        
        shortcutManager.registerHandler(for: .closeWindow) { [weak self] in
            WindowManager.shared.hideWindow()
        }
        
        shortcutManager.registerHandler(for: .toggleFocus) { [weak self] in
            self?.isSearchFocused.toggle()
        }
        
        // 操作快捷键
        shortcutManager.registerHandler(for: .copyItem) { [weak self] in
            self?.copyCurrentItem()
        }
        
        shortcutManager.registerHandler(for: .deleteItem) { [weak self] in
            self?.deleteCurrentItem()
        }
        
        shortcutManager.registerHandler(for: .toggleFavorite) { [weak self] in
            self?.toggleCurrentItemFavorite()
        }
    }
    
    private func setupNotificationObservers() {
        let navigateUpObserver = NotificationCenter.default.addObserver(
            forName: .navigateUp,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.navigateUp()
            }
        }
        
        let navigateDownObserver = NotificationCenter.default.addObserver(
            forName: .navigateDown,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.navigateDown()
            }
        }
        
        let selectItemObserver = NotificationCenter.default.addObserver(
            forName: .selectCurrentItem,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.selectCurrentItem()
            }
        }
        
        let numberSelectObserver = NotificationCenter.default.addObserver(
            forName: .selectItemByNumber,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let number = notification.object as? Int {
                Task { @MainActor in
                    _ = self?.selectByNumber(number)
                }
            }
        }
        
        let resetObserver = NotificationCenter.default.addObserver(
            forName: .resetSelection,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reset()
            }
        }
        
        let textInputObserver = NotificationCenter.default.addObserver(
            forName: .textInputCommand,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleTextInput(notification)
            }
        }
        
        let copyItemObserver = NotificationCenter.default.addObserver(
            forName: .copyCurrentItem,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.copyCurrentItem()
            }
        }
        
        observers = [navigateUpObserver, navigateDownObserver, selectItemObserver, 
                    numberSelectObserver, resetObserver, textInputObserver, copyItemObserver]
    }
    
    private func cleanupObservers() {
        let count = observers.count
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        if count > 0 {
            print("🧹 InputManager 清理了 \(count) 个通知观察者")
        }
    }
    
    // MARK: - Action Methods
    
    private func handleTextInput(_ notification: Notification) {
        guard let data = notification.object as? [String: Any],
              let action = data["action"] as? String else { return }
        
        switch action {
        case "backspace":
            if !searchText.isEmpty {
                searchText.removeLast()
            }
        case "insert":
            if let character = data["character"] as? String {
                searchText += character
            }
        default:
            break
        }
    }
    
    private func selectCurrentItem() {
        guard let item = selectedItem else { return }
        
        clipboardManager.copyToClipboard(item.content)
        
        WindowManager.shared.performDirectPaste()
    }
    
    private func copyCurrentItem() {
        guard let item = selectedItem else { return }
        clipboardManager.copyToClipboard(item.content)
    }
    
    private func deleteCurrentItem() {
        guard let item = selectedItem else { return }
        clipboardManager.deleteItem(item)
        handleItemDeletion()
    }
    
    private func toggleCurrentItemFavorite() {
        guard let item = selectedItem else { return }
        clipboardManager.toggleFavorite(for: item)
    }
    
}
