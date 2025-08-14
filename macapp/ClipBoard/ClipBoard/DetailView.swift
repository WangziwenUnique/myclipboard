import SwiftUI

struct DetailView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    let selectedItem: ClipboardItem?
    @State private var selectedTab = 0
    @State private var showSettingsPopover = false
    
    var body: some View {
        VStack(spacing: 0) {
            if let item = selectedItem {
                // 顶部工具栏
                DetailToolbar(
                    item: item,
                    clipboardManager: clipboardManager,
                    showSettingsPopover: $showSettingsPopover
                )
                
                // 内容区域 - 移除标签页，直接显示内容
                if item.type == .image {
                    ImageContentView(item: item)
                } else {
                    TextContentView(item: item)
                }
                
                // 底部元数据
                MetadataView(item: item)
            } else {
                // 空状态
                EmptyDetailView()
            }
        }
        .background(SidebarView.backgroundColor)
        .popover(isPresented: $showSettingsPopover, arrowEdge: .top) {
            SettingsPopoverView(showSettingsPopover: $showSettingsPopover)
                .frame(width: 320, height: 300)
        }
    }
}

struct DetailToolbar: View {
    let item: ClipboardItem
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var showSettingsPopover: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // 应用信息
                HStack(spacing: 8) {
                    Text("Application")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text(item.sourceApp)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // 右侧按钮组
                HStack(spacing: 12) {
                    // 收藏按钮
                    Button(action: {
                        clipboardManager.toggleFavorite(for: item)
                    }) {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                            .foregroundColor(item.isFavorite ? .yellow : .gray)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 复制按钮
                    Button(action: {
                        if item.type == .image, let imageData = item.imageData {
                            clipboardManager.copyImageToClipboard(imageData)
                        } else {
                            clipboardManager.copyToClipboard(item.content)
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.gray)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 更多选项按钮
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.gray)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 窗口按钮
                    Button(action: {}) {
                        Image(systemName: "rectangle.on.rectangle")
                            .foregroundColor(.gray)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
        .background(SidebarView.backgroundColor)
    }
}

struct ImageContentView: View {
    let item: ClipboardItem
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 16) {
                    imagePreviewContent(geometry: geometry)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
            }
        }
        .background(SidebarView.backgroundColor)
    }
    
    @ViewBuilder
    private func imagePreviewContent(geometry: GeometryProxy) -> some View {
        if let imageData = item.imageData,
           let nsImage = NSImage(data: imageData) {
            actualImageView(nsImage: nsImage, geometry: geometry)
        } else {
            placeholderImageView(geometry: geometry)
        }
    }
    
    private func actualImageView(nsImage: NSImage, geometry: GeometryProxy) -> some View {
        let maxWidth = geometry.size.width - 32
        let maxHeight = max(400, geometry.size.height - 100)
        
        return Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    private func placeholderImageView(geometry: GeometryProxy) -> some View {
        let maxWidth = geometry.size.width - 32
        let maxHeight = min(400, max(300, geometry.size.height - 100))
        
        return RoundedRectangle(cornerRadius: 8)
            .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            .overlay(placeholderContent)
    }
    
    private var placeholderContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Image Preview")
                .foregroundColor(.gray)
                .font(.system(size: 14))
            
            if let dimensions = item.imageDimensions {
                Text(dimensions)
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
            }
        }
    }
}

struct TextContentView: View {
    let item: ClipboardItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(SidebarView.backgroundColor)
    }
}

struct HTMLContentView: View {
    let item: ClipboardItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let htmlContent = item.htmlContent {
                    Text(htmlContent)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No HTML content")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("This item doesn't contain HTML content")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(16)
        }
    }
}

struct MetadataView: View {
    let item: ClipboardItem
    
    var body: some View {
        VStack(spacing: 0) {
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            VStack(spacing: 12) {
                // 类型和尺寸信息
                HStack {
                    Text("Type")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(item.type == .image ? "Image" : "Text")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                
                if item.type == .image {
                    HStack {
                        Text("Image dimensions")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(item.imageDimensions ?? "Unknown")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Image size")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(formatImageSize(item.imageSize))
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
                
                // 复制时间
                HStack {
                    Text("Copy time")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(item.timestamp, formatter: dateFormatter)")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(SidebarView.backgroundColor)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy, h:mm:ss a"
        return formatter
    }
    
    private func formatImageSize(_ size: Int64?) -> String {
        guard let size = size else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Select a clipboard item")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("Choose an item from the list to view its details")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SidebarView.backgroundColor)
    }
}

// 设置弹窗视图
struct SettingsPopoverView: View {
    @Binding var showSettingsPopover: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // 弹窗标题
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSettingsPopover = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Divider()
            
            // 设置选项
            VStack(spacing: 16) {
                SettingsRowView(
                    icon: "doc.on.clipboard",
                    title: "Auto Copy",
                    subtitle: "Automatically copy selected items"
                )
                
                SettingsRowView(
                    icon: "bell",
                    title: "Notifications",
                    subtitle: "Show clipboard notifications"
                )
                
                SettingsRowView(
                    icon: "paintbrush",
                    title: "Theme",
                    subtitle: "App appearance settings"
                )
                
                SettingsRowView(
                    icon: "trash",
                    title: "Clear History",
                    subtitle: "Remove all clipboard items"
                )
            }
            
            Spacer()
            
            // 底部按钮
            HStack(spacing: 12) {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSettingsPopover = false
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Done") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSettingsPopover = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 320, height: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
    }
}

// 设置行视图
struct SettingsRowView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            // 处理设置项点击
        }
    }
}

#Preview {
    DetailView(
        clipboardManager: ClipboardManager(),
        selectedItem: ClipboardItem(content: "Sample content", sourceApp: "Xcode")
    )
}
