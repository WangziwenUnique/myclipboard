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
                    .font(.system(size: 14))
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
                    .font(.system(size: 14))
                } else {
                    Text(text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(normalColor)
                        .font(.system(size: 14))
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
    @Binding var isSidebarVisible: Bool
    @Binding var isWindowPinned: Bool
    @State private var searchText = ""
    @State private var sortConfig = SortConfiguration()
    @State private var isSearchFocused = false
    
    var filteredItems: [ClipboardItem] {
        let items = clipboardManager.getSortedItems(
            for: category, 
            sortOption: sortConfig.option, 
            isReversed: sortConfig.isReversed
        )
        
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { item in
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
                .padding(.vertical, 12)
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
                    LazyVStack(spacing: 2) {
                        ForEach(filteredItems) { item in
                            ClipboardItemRow(
                                item: item,
                                isSelected: selectedItem?.id == item.id,
                                searchText: searchText
                            ) {
                                selectedItem = item
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
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
        .onAppear {
            // 窗口显示时自动聚焦搜索框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let searchText: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 项目图标
                Image(systemName: item.icon)
                    .foregroundColor(isSelected ? .blue : .gray)
                    .frame(width: 24, height: 24)
                
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
            .padding(.vertical, 12)
            .background(isSelected ? SidebarView.selectedBackgroundColor : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
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
        HStack(spacing: 8) {
            // 第一个图标：控制左侧菜单隐藏 - 强制显示
            Button(action: {
                isSidebarVisible.toggle()
            }) {
                Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Toggle sidebar")
            
            // 搜索框 - 背景色与父容器相同
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
            .padding(.vertical, 8)
            .background(Color(red: 0.05, green: 0.05, blue: 0.05)) // 与父容器背景相同
            .cornerRadius(8)
            
            // 第二个图标：控制窗口固定
            Button(action: {
                isWindowPinned.toggle()
            }) {
                Image(systemName: isWindowPinned ? "pin.fill" : "pin")
                    .foregroundColor(isWindowPinned ? .blue : .gray)
                    .font(.system(size: 15))
                    .frame(width: 16, height: 16)
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
                    .font(.system(size: 16))
                    .frame(width: 24, height: 16)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .buttonStyle(PlainButtonStyle())
            .menuIndicator(.hidden)
            .accentColor(.gray)
            .tint(.gray)
            .frame(width: 26, height: 16)
            .help("Sort options")
            
            // 第四个图标：显示快捷键
            Button(action: {
                showShortcutsPopup.toggle()
            }) {
                Image(systemName: "keyboard")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                    .frame(width: 16, height: 16)
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
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
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
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
    }
}

#Preview {
    ClipboardListView(
        clipboardManager: ClipboardManager(),
        selectedItem: .constant(nil),
        category: .history,
        isSidebarVisible: .constant(true),
        isWindowPinned: .constant(false)
    )
}

