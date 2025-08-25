import Foundation
import SwiftUI
import AppKit

// 统一的输入和选择管理器 - 合并KeyboardNavigationManager和SelectionManager
@MainActor
final class InputManager: ObservableObject {
    static var shared: InputManager? = nil
    
    private let clipboardManager: ClipboardManager
    private let shortcutManager: KeyboardShortcutManager
    
    // 配置单例实例
    static func configure(clipboardManager: ClipboardManager) {
        if shared == nil {
            shared = InputManager(
                clipboardManager: clipboardManager,
                shortcutManager: KeyboardShortcutManager.shared
            )
        }
    }
    
    // 访问单例的安全方法
    static func getInstance() -> InputManager {
        guard let instance = shared else {
            fatalError("InputManager.shared必须通过configure()方法初始化")
        }
        return instance
    }
    
    // Selection state - 原SelectionManager功能
    @Published private var selectedIndex: Int = 0
    private var items: [ClipboardItem] = []
    
    // Input state - 原KeyboardNavigationManager功能
    @Published var searchText: String = ""
    @Published var isSearchFocused: Bool = false
    
    // 防抖机制
    private var searchDebounceTimer: Timer?
    private var pendingSearchText: String = ""
    
    private var observers: [NSObjectProtocol] = []
    
    private init(clipboardManager: ClipboardManager, 
                 shortcutManager: KeyboardShortcutManager) {
        self.clipboardManager = clipboardManager
        self.shortcutManager = shortcutManager
    }
    
    deinit {
        // 同步清理观察者，避免actor隔离问题
        let count = observers.count
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        searchDebounceTimer?.invalidate()
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
        // 作为单例，只在应用退出时清理全局资源
        // 日常的隐藏/显示窗口操作不应该清理系统资源
        print("🔄 InputManager cleanup() - 单例模式下只清理状态，保留系统资源")
        
        // 只清理业务状态，不清理观察者和定时器
        reset()
        searchText = ""
        isSearchFocused = false
    }
    
    func cleanupGlobalResources() {
        // 应用退出时调用此方法清理全局资源
        cleanupObservers()
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = nil
    }
    
    // MARK: - Search Management
    
    func updateSearchText(_ newText: String) {
        pendingSearchText = newText
        
        // 立即处理空文本
        if newText.isEmpty {
            searchDebounceTimer?.invalidate()
            searchText = ""
            return
        }
        
        // 防抖处理非空文本
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.searchText = self?.pendingSearchText ?? ""
            }
        }
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
        
        
        // 搜索快捷键
        shortcutManager.registerHandler(for: .focusSearch) { [weak self] in
            self?.isSearchFocused = true
        }
        
        shortcutManager.registerHandler(for: .closeWindow) {
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
        
        
        let resetObserver = NotificationCenter.default.addObserver(
            forName: .resetSelection,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reset()
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
                    resetObserver, copyItemObserver]
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
