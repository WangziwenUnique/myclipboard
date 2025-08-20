import SwiftUI
import AppKit

// MARK: - Supporting Types

enum SortOption: CaseIterable {
    case lastCopyTime
    case firstCopyTime
    case numberOfCopies
    case size
    
    var displayName: String {
        switch self {
        case .lastCopyTime: return "Last Copy Time"
        case .firstCopyTime: return "First Copy Time"
        case .numberOfCopies: return "Number of Copies"
        case .size: return "Size"
        }
    }
}

struct SortConfiguration {
    var option: SortOption = .lastCopyTime
    var isReversed: Bool = false
    
    mutating func toggleReverse() {
        isReversed.toggle()
    }
}

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
    let category: ClipboardCategory
    let selectedApp: String?
    @Binding var isSidebarVisible: Bool
    @Binding var isWindowPinned: Bool
    @ObservedObject var shortcutManager: KeyboardShortcutManager
    
    // Simplified state management - 使用统一的InputManager
    @StateObject private var inputManager: InputManager
    @State private var sortConfig = SortConfiguration()
    
    init(clipboardManager: ClipboardManager,
         selectedItem: Binding<ClipboardItem?>,
         category: ClipboardCategory,
         selectedApp: String?,
         isSidebarVisible: Binding<Bool>,
         isWindowPinned: Binding<Bool>,
         shortcutManager: KeyboardShortcutManager) {
        self.clipboardManager = clipboardManager
        self._selectedItem = selectedItem
        self.category = category
        self.selectedApp = selectedApp
        self._isSidebarVisible = isSidebarVisible
        self._isWindowPinned = isWindowPinned
        self.shortcutManager = shortcutManager
        
        // 使用统一的InputManager替代两个分离的管理器
        self._inputManager = StateObject(wrappedValue: InputManager(
            clipboardManager: clipboardManager,
            shortcutManager: shortcutManager
        ))
    }
    
    // Simplified filtered items computation
    private var filteredItems: [ClipboardItem] {
        let items = clipboardManager.getSortedItems(
            for: category, 
            sortOption: sortConfig.option, 
            isReversed: sortConfig.isReversed
        )
        
        let appFilteredItems = selectedApp.map { app in
            items.filter { $0.sourceApp == app }
        } ?? items
        
        return inputManager.searchText.isEmpty ? appFilteredItems : 
            appFilteredItems.filter { item in
                item.content.localizedCaseInsensitiveContains(inputManager.searchText) ||
                item.sourceApp.localizedCaseInsensitiveContains(inputManager.searchText)
            }
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
            inputManager.cleanup()
        }
        .onChange(of: filteredItems) { _, items in
            inputManager.updateItems(items)
            selectedItem = inputManager.selectedItem
        }
        .onChange(of: inputManager.selectedItem) { _, item in
            selectedItem = item
        }
    }
    
    // MARK: - View Components
    
    private var searchBarSection: some View {
        SearchBarComponent(
            text: $inputManager.searchText,
            isSidebarVisible: $isSidebarVisible,
            isWindowPinned: $isWindowPinned,
            sortConfig: $sortConfig,
            shouldFocusOnAppear: true,
            onTextChange: { newText in
                inputManager.updateSearchText(newText)
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
            if inputManager.searchText.isEmpty {
                EmptyStateView(category: category)
            } else {
                SearchEmptyStateView(searchText: inputManager.searchText)
            }
        }
    }
    
    private var itemListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredItems) { item in
                    ClipboardItemRow(
                        item: item,
                        isSelected: inputManager.selectedItem?.id == item.id,
                        searchText: inputManager.searchText
                    ) {
                        inputManager.select(item: item)
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
        inputManager.updateItems(filteredItems)
        inputManager.setup()
        
        shortcutManager.updateListState(
            focusedOnList: false,
            currentIndex: inputManager.currentIndex,
            totalCount: filteredItems.count
        )
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

#Preview {
    ClipboardListView(
        clipboardManager: ClipboardManager(),
        selectedItem: .constant(nil),
        category: .history,
        selectedApp: nil,
        isSidebarVisible: .constant(true),
        isWindowPinned: .constant(false),
        shortcutManager: KeyboardShortcutManager.shared
    )
}

