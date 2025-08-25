import SwiftUI
import AppKit
import Combine

// MARK: - Text Highlighting

struct HighlightedText: View {
    let text: String
    let searchText: String
    let isSelected: Bool
    
    var body: some View {
        Group {
            if searchText.isEmpty {
                Text(text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(isSelected ? .white : .gray)
                    .font(.system(size: 12))
            } else {
                highlightedTextView
            }
        }
    }
    
    @ViewBuilder
    private var highlightedTextView: some View {
        let normalColor = isSelected ? Color.white : Color.gray
        let parts = text.components(separatedBy: .whitespacesAndNewlines).joined(separator: " ")
        
        // 使用简单字符串匹配替代正则表达式
        if parts.localizedCaseInsensitiveContains(searchText) {
            createSimpleHighlightedText(
                text: parts,
                searchText: searchText,
                normalColor: normalColor
            )
        } else {
            Text(parts)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(normalColor)
                .font(.system(size: 12))
        }
    }
    
    @ViewBuilder
    private func createSimpleHighlightedText(text: String, searchText: String, normalColor: Color) -> some View {
        let highlightColor = Color.yellow.opacity(0.6)
        
        // 简单的首次匹配高亮，避免复杂算法
        if let range = text.range(of: searchText, options: .caseInsensitive) {
            let beforeText = String(text[..<range.lowerBound])
            let matchText = String(text[range])
            let afterText = String(text[range.upperBound...])
            
            HStack(spacing: 0) {
                if !beforeText.isEmpty {
                    Text(beforeText)
                        .foregroundColor(normalColor)
                }
                Text(matchText)
                    .foregroundColor(.black)
                    .background(highlightColor)
                    .cornerRadius(2)
                if !afterText.isEmpty {
                    Text(afterText)
                        .foregroundColor(normalColor)
                }
            }
            .lineLimit(1)
            .font(.system(size: 12))
        } else {
            Text(text)
                .foregroundColor(normalColor)
                .lineLimit(1)
                .font(.system(size: 12))
        }
    }
}


// MARK: - Main View

struct ClipboardListView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var selectedItem: ClipboardItem?
    @Binding var category: ClipboardCategory
    let selectedApp: String?
    @Binding var isSidebarVisible: Bool
    @Binding var isWindowPinned: Bool
    @ObservedObject var shortcutManager: KeyboardShortcutManager
    
    // InputManager状态管理包装器
    @StateObject private var inputManagerWrapper = InputManagerWrapper()
    @State private var sortConfig = SortConfiguration()
    @State private var items: [ClipboardItem] = []
    
    init(clipboardManager: ClipboardManager,
         selectedItem: Binding<ClipboardItem?>,
         category: Binding<ClipboardCategory>,
         selectedApp: String?,
         isSidebarVisible: Binding<Bool>,
         isWindowPinned: Binding<Bool>,
         shortcutManager: KeyboardShortcutManager) {
        self.clipboardManager = clipboardManager
        self._selectedItem = selectedItem
        self._category = category
        self.selectedApp = selectedApp
        self._isSidebarVisible = isSidebarVisible
        self._isWindowPinned = isWindowPinned
        self.shortcutManager = shortcutManager
        
        // 确保InputManager单例已配置
        InputManager.configure(clipboardManager: clipboardManager)
    }
    
    // 简化的过滤逻辑：只处理应用过滤，搜索已在数据库层完成
    private var filteredItems: [ClipboardItem] {
        // 搜索时不需要UI层过滤，内存数据库LIKE查询已经处理
        if !inputManagerWrapper.searchText.isEmpty {
            return items
        }
        
        // 非搜索时只需要应用过滤
        return selectedApp.map { app in
            items.filter { $0.sourceApp == app }
        } ?? items
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBarSection
            separatorLine
            contentSection
        }
        .background(SidebarView.backgroundColor)
        .onAppear {
            setupView()
        }
        .onDisappear {
            // 作为单例，不在这里清理系统资源，只重置状态
            inputManagerWrapper.cleanup()
        }
        .onChange(of: filteredItems) { oldValue, newValue in
            inputManagerWrapper.updateItems(newValue)
            selectedItem = inputManagerWrapper.selectedItem
        }
        .onChange(of: inputManagerWrapper.selectedItem) { oldValue, newValue in
            selectedItem = newValue
        }
        .onChange(of: category) { oldValue, newValue in
            print("📝 Category changed from \(oldValue) to \(newValue)")
            DispatchQueue.main.async {
                loadData()
            }
        }
        .onChange(of: sortConfig) { oldValue, newValue in
            loadData()
        }
        .onChange(of: clipboardManager.dataDidChange) {
            loadData()  // 监听剪切板数据变化
        }
    }
    
    // MARK: - View Components
    
    private var searchBarSection: some View {
        SearchBarComponent(
            text: $inputManagerWrapper.searchText,
            isSidebarVisible: $isSidebarVisible,
            isWindowPinned: $isWindowPinned,
            sortConfig: $sortConfig,
            shouldFocusOnAppear: true,
            onTextChange: { newText in
                inputManagerWrapper.updateSearchText(newText)
                loadData()
            }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(SidebarView.backgroundColor)
    }
    
    private var separatorLine: some View {
        Rectangle()
            .fill(Color(red: 0.7, green: 0.7, blue: 0.7, opacity: 0.3))
            .frame(height: 0.5)
    }
    
    private var contentSection: some View {
        Group {
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                itemListView
            }
        }
    }
    
    private var emptyStateView: some View {
        Group {
            if inputManagerWrapper.searchText.isEmpty {
                EmptyStateView(category: category)
            } else {
                SearchEmptyStateView(searchText: inputManagerWrapper.searchText)
            }
        }
    }
    
    private var itemListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredItems) { item in
                    ClipboardItemRow(
                        item: item,
                        isSelected: inputManagerWrapper.selectedItem?.id == item.id,
                        searchText: inputManagerWrapper.searchText
                    ) {
                        inputManagerWrapper.select(item: item)
                    }
                    .contextMenu {
                        itemContextMenu(for: item)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private func itemContextMenu(for item: ClipboardItem) -> some View {
        Button("Copy") {
            clipboardManager.copyToClipboard(item.content)
        }
        
        Button("Delete") {
            clipboardManager.deleteItem(item)
        }
        
        Divider()
        
        Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            clipboardManager.toggleFavorite(for: item)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupView() {
        loadData()
        inputManagerWrapper.setup()
        
        shortcutManager.updateListState(
            focusedOnList: false,
            currentIndex: inputManagerWrapper.currentIndex,
            totalCount: filteredItems.count
        )
    }
    
    private func loadData() {
        let loadedItems: [ClipboardItem]
        
        if inputManagerWrapper.searchText.isEmpty {
            loadedItems = clipboardManager.getSortedItems(
                for: category,
                sortOption: sortConfig.option,
                isReversed: sortConfig.isReversed
            )
        } else {
            loadedItems = clipboardManager.searchItems(
                query: inputManagerWrapper.searchText,
                sourceApp: selectedApp
            )
        }
        
        self.items = loadedItems
        inputManagerWrapper.updateItems(filteredItems)
        selectedItem = inputManagerWrapper.selectedItem
    }
    
}

// MARK: - Supporting Views

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let searchText: String
    let action: () -> Void
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .foregroundColor(isSelected ? .blue : .gray)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                HighlightedText(
                    text: item.displayContent,
                    searchText: searchText,
                    isSelected: isSelected
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? SidebarView.selectedBackgroundColor : 
                      (isHovered ? Color(red: 0.18, green: 0.18, blue: 0.18) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct SearchEmptyStateView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No results found")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("No items match \"\(searchText)\"")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SidebarView.backgroundColor)
    }
}

struct EmptyStateView: View {
    let category: ClipboardCategory
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No \(category.rawValue.lowercased()) items")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("Your \(category.rawValue.lowercased()) items will appear here")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SidebarView.backgroundColor)
    }
}

// InputManager包装器，用于在SwiftUI中正确处理单例观察
@MainActor
final class InputManagerWrapper: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    var inputManager: InputManager {
        InputManager.getInstance()
    }
    
    init() {
        // 设置观察
        setupObservation()
    }
    
    private func setupObservation() {
        // 延迟设置观察，直到InputManager配置完成
        DispatchQueue.main.async { [weak self] in
            self?.bindToInputManager()
        }
    }
    
    private func bindToInputManager() {
        // 监听InputManager的变化并转发给SwiftUI
        inputManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // 代理所有需要监听的属性
    var searchText: String {
        get { inputManager.searchText }
        set { inputManager.updateSearchText(newValue) }
    }
    
    var isSearchFocused: Bool {
        get { inputManager.isSearchFocused }
        set { inputManager.isSearchFocused = newValue }
    }
    
    var selectedItem: ClipboardItem? {
        inputManager.selectedItem
    }
    
    var currentIndex: Int {
        inputManager.currentIndex
    }
    
    func updateSearchText(_ text: String) {
        inputManager.updateSearchText(text)
    }
    
    func updateItems(_ items: [ClipboardItem]) {
        inputManager.updateItems(items)
    }
    
    func select(item: ClipboardItem) {
        inputManager.select(item: item)
    }
    
    func setup() {
        inputManager.setup()
        // 重新绑定观察（防止setup过程中的变化）
        bindToInputManager()
    }
    
    func cleanup() {
        inputManager.cleanup()
    }
}

#Preview {
    ClipboardListView(
        clipboardManager: ClipboardManager(),
        selectedItem: .constant(nil),
        category: .constant(.history),
        selectedApp: nil,
        isSidebarVisible: .constant(true),
        isWindowPinned: .constant(false),
        shortcutManager: KeyboardShortcutManager.shared
    )
}

