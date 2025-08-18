import SwiftUI
import AppKit

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
                // 根据选中状态调整高亮颜色，确保良好的对比度
                let highlightColor = isSelected ? Color.yellow : Color.yellow
                let highlightTextColor = Color.black
                let normalColor = isSelected ? Color.white : Color.gray
                
                // 使用不区分大小写的搜索分割文本
                let parts = text.components(separatedBy: .whitespacesAndNewlines).joined(separator: " ")
                let regex = try! NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: searchText), options: .caseInsensitive)
                let range = NSRange(location: 0, length: parts.utf16.count)
                let matches = regex.matches(in: parts, options: [], range: range)
                
                if !matches.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(createHighlightedTextParts(from: parts, matches: matches, highlightColor: highlightColor, highlightTextColor: highlightTextColor, normalColor: normalColor), id: \.id) { part in
                            part.text
                        }
                    }
                    .lineLimit(1)
                    .font(.system(size: 12))
                } else {
                    Text(text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(normalColor)
                        .font(.system(size: 12))
                }
            }
        }
    }
    
    private func createHighlightedTextParts(from parts: String, matches: [NSTextCheckingResult], highlightColor: Color, highlightTextColor: Color, normalColor: Color) -> [TextPart] {
        var result: [TextPart] = []
        var lastEnd = 0
        
        for match in matches {
            // 添加匹配前的文本
            if match.range.location > lastEnd {
                let beforeText = String(parts[parts.index(parts.startIndex, offsetBy: lastEnd)..<parts.index(parts.startIndex, offsetBy: match.range.location)])
                if !beforeText.isEmpty {
                    result.append(TextPart(id: UUID(), text: AnyView(Text(beforeText).foregroundColor(normalColor))))
                }
            }
            
            // 添加高亮的匹配文本
            let matchText = String(parts[parts.index(parts.startIndex, offsetBy: match.range.location)..<parts.index(parts.startIndex, offsetBy: match.range.location + match.range.length)])
            result.append(TextPart(id: UUID(), text: AnyView(Text(matchText)
                .foregroundColor(highlightTextColor)
                .padding(.horizontal, 2)
                .background(highlightColor)
                .cornerRadius(2))))
            
            lastEnd = match.range.location + match.range.length
        }
        
        // 添加剩余文本
        if lastEnd < parts.count {
            let remainingText = String(parts[parts.index(parts.startIndex, offsetBy: lastEnd)...])
            if !remainingText.isEmpty {
                result.append(TextPart(id: UUID(), text: AnyView(Text(remainingText).foregroundColor(normalColor))))
            }
        }
        
        return result
    }
}

struct TextPart: Identifiable {
    let id: UUID
    let text: AnyView
}

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

struct KeyboardShortcutsPopup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 4)
            
            Group {
                ShortcutRow(key: "⌘1", description: "History")
                ShortcutRow(key: "⌘2", description: "Favorites")
                ShortcutRow(key: "⌘3", description: "Files")
                ShortcutRow(key: "⌘4", description: "Images")
                ShortcutRow(key: "⌘5", description: "Links")
                ShortcutRow(key: "⌘6", description: "Code")
                ShortcutRow(key: "⌘7", description: "Mail")
                
                Divider().background(Color.gray)
                
                ShortcutRow(key: "⌘C", description: "Copy selected item")
                ShortcutRow(key: "⌘V", description: "Paste from clipboard")
                ShortcutRow(key: "⌘F", description: "Focus search")
                ShortcutRow(key: "⌘A", description: "Select all in search")
                ShortcutRow(key: "⌘W", description: "Close window")
                ShortcutRow(key: "⌘,", description: "Preferences")
            }
        }
        .padding(16)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .cornerRadius(8)
        .frame(width: 240)
    }
}

struct ShortcutRow: View {
    let key: String
    let description: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(red: 0.25, green: 0.25, blue: 0.25))
                .cornerRadius(4)
            
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}

struct ClipboardListView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var selectedItem: ClipboardItem?
    let category: ClipboardCategory
    let selectedApp: String?  // 新增：选中的应用筛选
    @Binding var isSidebarVisible: Bool
    @Binding var isWindowPinned: Bool
    @ObservedObject var shortcutManager: KeyboardShortcutManager
    @State private var searchText = ""
    @State private var sortConfig = SortConfiguration()
    @State private var isSearchFocused = false
    @State private var currentSelectedIndex: Int = 0
    
    var filteredItems: [ClipboardItem] {
        let items = clipboardManager.getSortedItems(
            for: category, 
            sortOption: sortConfig.option, 
            isReversed: sortConfig.isReversed
        )
        
        // 首先按应用筛选（如果设置了应用筛选）
        let appFilteredItems: [ClipboardItem]
        if let selectedApp = selectedApp {
            appFilteredItems = items.filter { $0.sourceApp == selectedApp }
        } else {
            appFilteredItems = items
        }
        
        // 然后按搜索文本筛选
        if searchText.isEmpty {
            return appFilteredItems
        } else {
            return appFilteredItems.filter { item in
                item.content.localizedCaseInsensitiveContains(searchText) ||
                item.sourceApp.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar at the top
            SearchBar(
                text: $searchText,
                isSidebarVisible: $isSidebarVisible,
                isWindowPinned: $isWindowPinned,
                sortConfig: $sortConfig,
                isSearchFocused: $isSearchFocused
            )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(SidebarView.backgroundColor)
            
            // Separator line
            Rectangle()
                .fill(Color(red: 0.7, green: 0.7, blue: 0.7, opacity: 0.3))
                .frame(height: 0.5)
            
            if filteredItems.isEmpty {
                if searchText.isEmpty {
                    EmptyStateView(category: category)
                } else {
                    SearchEmptyStateView(searchText: searchText)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredItems) { item in
                            ClipboardItemRow(
                                item: item,
                                isSelected: selectedItem?.id == item.id,
                                searchText: searchText
                            ) {
                                // 鼠标点击时同步更新索引和选择项
                                if let index = filteredItems.firstIndex(of: item) {
                                    print("🖱️ [ClipboardListView] 鼠标点击项目，索引: \(index)")
                                    updateSelection(to: index)
                                }
                            }
                            .contextMenu {
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
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(SidebarView.backgroundColor)
        .onAppear {
            print("👁️ [ClipboardListView] onAppear 被调用")
            // 每次窗口显示时重置选择索引到第一条
            if !filteredItems.isEmpty {
                print("   - 重置选择到第一项")
                updateSelection(to: 0)
            } else {
                print("   - 列表为空，重置索引为0")
                currentSelectedIndex = 0
                selectedItem = nil
            }
            
            // 窗口显示时自动聚焦搜索框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
            setupListKeyboardShortcuts()
            setupNotificationObservers()
        }
        .onChange(of: filteredItems) { items in
            // 更新快捷键管理器的列表状态
            shortcutManager.updateListState(
                focusedOnList: !isSearchFocused,
                currentIndex: currentSelectedIndex,
                totalCount: items.count
            )
            
            // 如果当前选择的索引超出范围，重置为0
            if currentSelectedIndex >= items.count && !items.isEmpty {
                print("⚠️ [ClipboardListView] 索引超出范围，重置到第一项")
                updateSelection(to: 0)
            }
        }
        .onChange(of: isSearchFocused) { focused in
            shortcutManager.isSearchFocused = focused
            shortcutManager.isListFocused = !focused
        }
    }
    
    // MARK: - 列表快捷键设置
    private func setupListKeyboardShortcuts() {
        // 列表导航快捷键
        shortcutManager.registerHandler(for: .navigateUp) {
            navigateUp()
        }
        
        shortcutManager.registerHandler(for: .navigateDown) {
            navigateDown()
        }
        
        shortcutManager.registerHandler(for: .selectItem) {
            selectCurrentItem()
        }
        
        shortcutManager.registerHandler(for: .jumpToTop) {
            jumpToTop()
        }
        
        shortcutManager.registerHandler(for: .jumpToBottom) {
            jumpToBottom()
        }
        
        // 数字键快速选择
        shortcutManager.registerHandler(for: .selectItem1) { selectItemByNumber(1) }
        shortcutManager.registerHandler(for: .selectItem2) { selectItemByNumber(2) }
        shortcutManager.registerHandler(for: .selectItem3) { selectItemByNumber(3) }
        shortcutManager.registerHandler(for: .selectItem4) { selectItemByNumber(4) }
        shortcutManager.registerHandler(for: .selectItem5) { selectItemByNumber(5) }
        shortcutManager.registerHandler(for: .selectItem6) { selectItemByNumber(6) }
        shortcutManager.registerHandler(for: .selectItem7) { selectItemByNumber(7) }
        shortcutManager.registerHandler(for: .selectItem8) { selectItemByNumber(8) }
        shortcutManager.registerHandler(for: .selectItem9) { selectItemByNumber(9) }
        
        // 搜索快捷键
        shortcutManager.registerHandler(for: .focusSearch) {
            isSearchFocused = true
        }
        
        shortcutManager.registerHandler(for: .clearSearchOrClose) {
            if !searchText.isEmpty {
                searchText = ""
            } else if isSearchFocused {
                // 如果搜索框为空且有焦点，则将焦点返回列表
                isSearchFocused = false
            } else {
                // 关闭窗口
                if let window = NSApp.keyWindow {
                    window.orderOut(nil)
                }
            }
        }
        
        shortcutManager.registerHandler(for: .toggleFocus) {
            isSearchFocused.toggle()
        }
        
        // 操作快捷键
        shortcutManager.registerHandler(for: .copyItem) {
            copyCurrentItem()
        }
        
        shortcutManager.registerHandler(for: .deleteItem) {
            deleteCurrentItem()
        }
        
        shortcutManager.registerHandler(for: .toggleFavorite) {
            toggleCurrentItemFavorite()
        }
    }
    
    // MARK: - 选择管理方法
    private func updateSelection(to index: Int) {
        guard !filteredItems.isEmpty, index >= 0, index < filteredItems.count else {
            print("   - ❌ 无效的选择索引: \(index), 列表长度: \(filteredItems.count)")
            return
        }
        
        let oldIndex = currentSelectedIndex
        currentSelectedIndex = index
        selectedItem = filteredItems[index]
        
        print("   - 🔄 选择更新：\(oldIndex) -> \(currentSelectedIndex)")
        print("   - 📋 selectedItem.id: \(selectedItem?.id.uuidString ?? "nil")")
        
        // 验证同步状态
        validateSelectionSync()
    }
    
    private func validateSelectionSync() {
        let isIndexValid = currentSelectedIndex >= 0 && currentSelectedIndex < filteredItems.count
        let isItemSync = isIndexValid && filteredItems[currentSelectedIndex].id == selectedItem?.id
        
        if !isIndexValid {
            print("   - ⚠️ 索引不合法: \(currentSelectedIndex), 范围: 0..<\(filteredItems.count)")
        } else if !isItemSync {
            print("   - ⚠️ 项目不同步: 索引\(currentSelectedIndex)对应\(filteredItems[currentSelectedIndex].id.uuidString)，但selectedItem是\(selectedItem?.id.uuidString ?? "nil")")
        } else {
            print("   - ✅ 选择状态同步正常")
        }
    }
    
    // MARK: - 导航辅助方法
    private func navigateUp() {
        print("⬆️ [ClipboardListView] navigateUp() 被调用")
        print("   - filteredItems.count: \(filteredItems.count)")
        print("   - isSearchFocused: \(isSearchFocused)")
        print("   - currentSelectedIndex: \(currentSelectedIndex)")
        
        guard !filteredItems.isEmpty else { 
            print("   - ❌ 导航条件不满足，跳过")
            return 
        }
        
        let newIndex = max(0, currentSelectedIndex - 1)
        updateSelection(to: newIndex)
        print("   - ✅ 向上导航完成")
    }
    
    private func navigateDown() {
        print("⬇️ [ClipboardListView] navigateDown() 被调用")
        print("   - filteredItems.count: \(filteredItems.count)")
        print("   - isSearchFocused: \(isSearchFocused)")
        print("   - currentSelectedIndex: \(currentSelectedIndex)")
        
        guard !filteredItems.isEmpty else { 
            print("   - ❌ 导航条件不满足，跳过")
            return 
        }
        
        let newIndex = min(filteredItems.count - 1, currentSelectedIndex + 1)
        updateSelection(to: newIndex)
        print("   - ✅ 向下导航完成")
    }
    
    private func selectCurrentItem() {
        guard !filteredItems.isEmpty else { return }
        let item = filteredItems[currentSelectedIndex]
        
        // 将选中内容复制到系统剪贴板
        clipboardManager.copyToClipboard(item.content)
        
        // 直接粘贴到当前激活的应用
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.performDirectPaste()
        } else {
            // 如果无法获取AppDelegate，则只关闭窗口
            if let window = NSApp.keyWindow {
                window.orderOut(nil)
            }
        }
    }
    
    private func jumpToTop() {
        guard !filteredItems.isEmpty else { return }
        updateSelection(to: 0)
    }
    
    private func jumpToBottom() {
        guard !filteredItems.isEmpty else { return }
        updateSelection(to: filteredItems.count - 1)
    }
    
    private func selectItemByNumber(_ number: Int) {
        guard !filteredItems.isEmpty else { return }
        if let index = shortcutManager.getListIndexForNumber(number) {
            updateSelection(to: index)
        }
    }
    
    private func copyCurrentItem() {
        guard let item = selectedItem else { return }
        clipboardManager.copyToClipboard(item.content)
    }
    
    private func deleteCurrentItem() {
        guard let item = selectedItem else { return }
        print("🗑️ [ClipboardListView] 删除当前项目，索引: \(currentSelectedIndex)")
        clipboardManager.deleteItem(item)
        
        // 删除后重新选择适当的项目
        if !filteredItems.isEmpty {
            let newIndex = min(currentSelectedIndex, filteredItems.count - 1)
            print("   - 删除后重新选择索引: \(newIndex)")
            updateSelection(to: newIndex)
        } else {
            print("   - 列表为空，清空选择")
            currentSelectedIndex = 0
            selectedItem = nil
        }
    }
    
    private func toggleCurrentItemFavorite() {
        guard let item = selectedItem else { return }
        clipboardManager.toggleFavorite(for: item)
    }
    
    // 设置通知监听器（用于全局快捷键处理）
    private func setupNotificationObservers() {
        print("🔧 [ClipboardListView] 设置通知监听器")
        
        NotificationCenter.default.addObserver(
            forName: .navigateUp,
            object: nil,
            queue: .main
        ) { _ in
            print("📤 [ClipboardListView] 收到向上导航通知")
            self.navigateUp()
        }
        
        NotificationCenter.default.addObserver(
            forName: .navigateDown,
            object: nil,
            queue: .main
        ) { _ in
            print("📤 [ClipboardListView] 收到向下导航通知")
            self.navigateDown()
        }
        
        NotificationCenter.default.addObserver(
            forName: .selectCurrentItem,
            object: nil,
            queue: .main
        ) { _ in
            print("📤 [ClipboardListView] 收到选择当前项通知")
            self.selectCurrentItem()
        }
        
        NotificationCenter.default.addObserver(
            forName: .selectItemByNumber,
            object: nil,
            queue: .main
        ) { notification in
            if let number = notification.object as? Int {
                print("📤 [ClipboardListView] 收到数字选择通知: \(number)")
                self.selectItemByNumber(number)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .resetSelection,
            object: nil,
            queue: .main
        ) { _ in
            print("📤 [ClipboardListView] 收到重置选择通知")
            if !self.filteredItems.isEmpty {
                print("   - 重置选择到第一项")
                self.updateSelection(to: 0)
            } else {
                print("   - 列表为空，重置索引为0")
                self.currentSelectedIndex = 0
                self.selectedItem = nil
            }
        }
        
        print("✅ [ClipboardListView] 通知监听器设置完成")
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let searchText: String
    let action: () -> Void
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 项目图标
            Image(systemName: item.icon)
                .foregroundColor(isSelected ? .blue : .gray)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                // 主要内容 - 使用高亮文本组件
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

struct SearchBar: View {
    @Binding var text: String
    @Binding var isSidebarVisible: Bool
    @Binding var isWindowPinned: Bool
    @Binding var sortConfig: SortConfiguration
    @Binding var isSearchFocused: Bool
    @State private var showShortcutsPopup = false
    @FocusState private var textFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 第一个图标：控制左侧菜单隐藏 - 强制显示
            Button(action: {
                isSidebarVisible.toggle()
            }) {
                Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Toggle sidebar")
            
            // 搜索框 - 增强视觉层次
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                    .frame(width: 16, height: 16)
                
                TextField("Type to search...", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .focused($textFieldFocused)
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(SidebarView.backgroundColor)
            .cornerRadius(12)
            
            // 第二个图标：控制窗口固定
            Button(action: {
                isWindowPinned.toggle()
            }) {
                Image(systemName: isWindowPinned ? "pin.fill" : "pin")
                    .foregroundColor(isWindowPinned ? .blue : .gray)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(45))
            }
            .buttonStyle(PlainButtonStyle())
            .help(isWindowPinned ? "Unpin window" : "Pin window")
            
            // 第三个图标：排序选项
            Menu {
                Button("Last Copy Time") {
                    sortConfig.option = .lastCopyTime
                }
                Button("First Copy Time") {
                    sortConfig.option = .firstCopyTime
                }
                Button("Number of Copies") {
                    sortConfig.option = .numberOfCopies
                }
                Button("Size") {
                    sortConfig.option = .size
                }
                Divider()
                Button(sortConfig.isReversed ? "Normal Order" : "Reverse Order") {
                    sortConfig.toggleReverse()
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.gray)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .buttonStyle(PlainButtonStyle())
            .menuIndicator(.hidden)
            .accentColor(.gray)
            .tint(.gray)
            .frame(width: 20, height: 20)
            .help("Sort options")
            
            // 第四个图标：显示快捷键
            Button(action: {
                showShortcutsPopup.toggle()
            }) {
                Image(systemName: "keyboard")
                    .foregroundColor(.gray)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Show keyboard shortcuts")
            .popover(isPresented: $showShortcutsPopup, arrowEdge: .bottom) {
                KeyboardShortcutsPopup()
            }
        }
        .padding(.horizontal, 4)
        .onAppear {
            // 窗口显示时自动聚焦搜索框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                textFieldFocused = true
            }
        }
        .onChange(of: isSearchFocused) {
            textFieldFocused = isSearchFocused
        }
        .onChange(of: textFieldFocused) {
            isSearchFocused = textFieldFocused
        }
        .background(
            // 隐藏的快捷键处理
            Button("") {
                if textFieldFocused {
                    // 全选搜索框文本
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
            }
            .keyboardShortcut("a", modifiers: .command)
            .hidden()
        )
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
        selectedApp: nil,  // 添加新的必需参数
        isSidebarVisible: .constant(true),
        isWindowPinned: .constant(false),
        shortcutManager: KeyboardShortcutManager.shared
    )
}

