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
                } else if item.type == .link {
                    LinkContentView(item: item)
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

struct LinkContentView: View {
    let item: ClipboardItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 链接预览卡片
                LinkPreviewView(url: item.content)
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
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
                // 应用来源
                HStack {
                    Text("Application")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // 应用图标
                        if let bundleID = item.sourceAppBundleID,
                           let appIcon = AppIconHelper.shared.getAppIcon(for: bundleID) {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        } else if let appIcon = AppIconHelper.shared.getAppIcon(for: item.sourceApp) {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "app.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        
                        Text(item.sourceApp)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
                
                // 类型
                HStack {
                    Text("Types")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(getTypeDisplayText())
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                
                // 复制次数（仅当大于1时显示）
                if item.copyCount > 1 {
                    HStack {
                        Text("Number of copies")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("\(item.copyCount)")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
                
                // 根据不同类型显示特定属性
                getTypeSpecificViews()
                
                // 时间信息
                getTimeViews()
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
    
    private func getTypeDisplayText() -> String {
        switch item.type {
        case .text: return "Text"
        case .image: return "Image" 
        case .link: return "Link"
        case .file: return "File"
        case .email: return "Email"
        }
    }
    
    @ViewBuilder
    private func getTypeSpecificViews() -> some View {
        switch item.type {
        case .image:
            imageSpecificViews()
        case .text:
            textSpecificViews()
        case .link:
            linkSpecificViews()
        case .file:
            fileSpecificViews()
        case .email:
            emailSpecificViews()
        }
    }
    
    @ViewBuilder
    private func imageSpecificViews() -> some View {
        // 文件路径（仅当来自文件时显示）
        if let filePath = item.filePath {
            HStack {
                Text("Path")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(filePath)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        
        // 文件大小
        HStack {
            Text("File size")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(formatImageSize(item.imageSize))
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
        
        // 图片尺寸
        HStack {
            Text("Image dimensions")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(item.imageDimensions ?? "Unknown")
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
    }
    
    @ViewBuilder
    private func textSpecificViews() -> some View {
        // 字符数
        if let characterCount = item.characterCount {
            HStack {
                Text("Characters")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(characterCount)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
        
        // 行数
        if let lineCount = item.lineCount {
            HStack {
                Text("Lines")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(lineCount)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
        
        // 内容大小
        if let contentSize = item.contentSize {
            HStack {
                Text("Content size")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(formatImageSize(contentSize))
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
    }
    
    @ViewBuilder
    private func linkSpecificViews() -> some View {
        // URL
        HStack {
            Text("URL")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(item.content)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        
        // 域名
        if let domain = item.domain {
            HStack {
                Text("Domain")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(domain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
        
        // 协议
        if let urlProtocol = item.urlProtocol {
            HStack {
                Text("Protocol")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(urlProtocol.uppercased())
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
    }
    
    @ViewBuilder
    private func fileSpecificViews() -> some View {
        // 文件路径
        HStack {
            Text("Path")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(item.content)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        
        // 文件扩展名
        if let fileExtension = item.fileExtension {
            HStack {
                Text("File extension")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(fileExtension.uppercased())
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
        
        // 文件大小
        if let imageSize = item.imageSize {
            HStack {
                Text("File size")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(formatImageSize(imageSize))
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
    }
    
    @ViewBuilder
    private func emailSpecificViews() -> some View {
        // 邮箱地址
        HStack {
            Text("Email")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(item.content)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        
        // 邮箱域名
        if let domain = item.emailDomain {
            HStack {
                Text("Domain")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(domain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
        
        // 字符数
        if let characterCount = item.characterCount {
            HStack {
                Text("Characters")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(characterCount)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
    }
    
    @ViewBuilder
    private func getTimeViews() -> some View {
        if item.copyCount > 1 {
            // 首次复制时间
            HStack {
                Text("First copy time")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(item.firstCopyTime, formatter: dateFormatter)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            
            // 最后复制时间
            HStack {
                Text("Last copy time")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(item.lastCopyTime, formatter: dateFormatter)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        } else {
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
