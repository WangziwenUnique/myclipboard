import SwiftUI

struct ClipboardListView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var selectedItem: ClipboardItem?
    let category: ClipboardCategory
    @State private var searchText = ""
    
    var filteredItems: [ClipboardItem] {
        let items = clipboardManager.getItemsByCategory(category)
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
            SearchBar(text: $searchText)
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
                                isSelected: selectedItem?.id == item.id
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
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 项目图标
                Image(systemName: item.icon)
                    .foregroundColor(isSelected ? .blue : .gray)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    // 主要内容
                    Text(item.displayContent)
                        .lineLimit(3)
                        .foregroundColor(isSelected ? .white : .gray)
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 14))
                    
                    // 元数据
                    HStack(spacing: 8) {
                        Text(item.sourceApp)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        
                        Text(item.timestamp, style: .relative)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        
                        if item.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 10))
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    // 类型标签
                    Text(item.type.rawValue)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(3)
                    
                    // 图片尺寸信息（如果是图片）
                    if item.type == .image {
                        Text("3570x1066")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
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
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Type to search...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SidebarView.buttonBackgroundColor)
        .cornerRadius(8)
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
        category: .history
    )
}
