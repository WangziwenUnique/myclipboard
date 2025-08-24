import SwiftUI

// 自定义工具提示组件 - 增强版悬浮弹窗
struct CustomTooltip: View {
    let text: String
    let shortcut: String?
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 8) {
            // 主标题
            Text(text)
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .semibold))
            
            // 快捷键信息 - 显示在同一行
            if let shortcut = shortcut {
                Text(shortcut)
                    .foregroundColor(.white)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.25, green: 0.25, blue: 0.25))
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(red: 0.3, green: 0.3, blue: 0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 2, y: 2)
        )
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.85)
        .offset(y: isVisible ? 0 : 5)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
                isVisible = true
            }
        }
    }
}

// ClipboardCategory 扩展，添加快捷键信息
extension ClipboardCategory {
    var shortcut: String? {
        switch self {
        case .history: return "⌘1"
        case .favorites: return "⌘2"
        case .text: return "⌘3"
        case .images: return "⌘4"
        case .links: return "⌘5"
        case .files: return "⌘6"
        case .mail: return "⌘7"
        }
    }
    
    var displayName: String {
        switch self {
        case .history: return "History"
        case .favorites: return "Favorites"
        case .text: return "Text"
        case .images: return "Images"
        case .links: return "Links"
        case .files: return "Files"
        case .mail: return "Mail"
        }
    }
}

struct SidebarView: View {
    // 统一的颜色方案
    static let backgroundColor = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let selectedBackgroundColor = Color(red: 0.22, green: 0.22, blue: 0.22)
    static let buttonBackgroundColor = Color(red: 0.18, green: 0.18, blue: 0.18)
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var selectedCategory: ClipboardCategory
    @Binding var selectedApp: String?  // 新增：选中的应用筛选
    var onTooltip: ((ContentView.GlobalTooltipData?) -> Void)? = nil
    var sidebarWidth: CGFloat = 50 // 默认宽度
    
    // 应用图标展开状态
    @State private var isAppSectionExpanded: Bool = false
    // 下拉按钮悬浮状态
    @State private var isDropdownHovered: Bool = false
    // 可用应用列表
    @State private var availableApps: [String] = []
    
    // 常用分类清单（不包含 history）
    private let commonCategories: [ClipboardCategory] = [.favorites, .text, .images, .links, .files, .mail]
    
    // 获取可用应用列表
    private var appSourceIcons: [String] {
        return availableApps
    }
    
    // 显示的应用图标列表（根据展开状态决定）
    private var displayedAppIcons: [String] {
        if isAppSectionExpanded {
            return appSourceIcons
        } else {
            // 只显示最新的一个应用
            return Array(appSourceIcons.prefix(1))
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 第一部分：固定置顶的 History
            VStack(spacing: 4) {
                CategoryIconRow(
                    category: .history,
                    isSelected: selectedCategory == .history,
                    onTooltip: onTooltip
                ) {
                    selectedCategory = .history
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 8)

            // 第二部分：常用分类（收藏、文件、图片、链接、代码、邮件）
            VStack(spacing: 3) {
                ForEach(commonCategories, id: \.self) { category in
                    CategoryIconRow(
                        category: category,
                        isSelected: selectedCategory == category,
                        onTooltip: onTooltip,
                        sidebarWidth: sidebarWidth
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.vertical, 8)

            // 第二和第三部分之间的间距（固定12px）
            Spacer()
                .frame(height: 12)

            // 第三部分：应用来源图标（可折叠）
            VStack(spacing: 4) {
                // 显示应用图标
                ForEach(displayedAppIcons, id: \.self) { app in
                    AppIconRow(
                        appName: app, 
                        isSelected: selectedApp == app,  // 传递选中状态
                        onTooltip: onTooltip, 
                        sidebarWidth: sidebarWidth
                    ) {
                        // 应用筛选逻辑：点击相同应用取消筛选，点击不同应用设置筛选
                        if selectedApp == app {
                            selectedApp = nil  // 取消筛选
                        } else {
                            selectedApp = app  // 设置应用筛选
                            selectedCategory = .history  // 切换到历史类别显示所有该应用的记录
                        }
                    }
                }
                
                // 展开/折叠按钮（仅在有多个应用时显示）
                if appSourceIcons.count > 1 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isAppSectionExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isAppSectionExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(isDropdownHovered ? .white : .gray)
                            .frame(width: 14, height: 14)
                            .frame(width: 30, height: 26)
                            .background(
                                isDropdownHovered ? Color(red: 0.25, green: 0.25, blue: 0.25) : Color.clear
                            )
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isDropdownHovered = hovering
                        }
                    }
                    .help(isAppSectionExpanded ? "折叠应用列表" : "展开应用列表 (\(appSourceIcons.count))")
                }
            }
            .padding(.bottom, 12)
            
            // 占据剩余空间，让第三部分靠近第二部分
            Spacer()

            // 底部控制栏（保留）
            // CompactBottomControlBar()
        }
        .background(SidebarView.backgroundColor)
        .onAppear {
            availableApps = clipboardManager.getDistinctSourceApps()
        }
    }
}

struct CategoryIconRow: View {
    let category: ClipboardCategory
    let isSelected: Bool
    var onTooltip: ((ContentView.GlobalTooltipData?) -> Void)? = nil
    var sidebarWidth: CGFloat = 50
    let action: () -> Void
    @State private var isHovered: Bool = false
    @State private var showTooltip: Bool = false
    
    // 固定按钮和图标尺寸
    private let buttonSize: CGFloat = 26
    private let iconSize: CGFloat = 14
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Button(action: action) {
                    VStack(spacing: 2) {
                        Image(systemName: category.icon)
                            .foregroundColor(isSelected ? .blue : (isHovered ? .white : .gray))
                            .frame(width: iconSize, height: iconSize)
                    }
                    .frame(width: buttonSize, height: buttonSize)
                    .background(
                        isSelected ? SidebarView.selectedBackgroundColor :
                        (isHovered ? Color(red: 0.25, green: 0.25, blue: 0.25) : Color.clear)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                    
                    if hovering {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if isHovered {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showTooltip = true
                                    // 使用全局弹窗回调 - 根据实际菜单项位置计算
                                    let localFrame = geometry.frame(in: .named("ContentView"))
                                    onTooltip?(ContentView.GlobalTooltipData.createForMenuItem(
                                        text: category.displayName,
                                        shortcut: category.shortcut,
                                        itemFrame: localFrame,
                                        sidebarWidth: sidebarWidth
                                    ))
                                }
                            }
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showTooltip = false
                            onTooltip?(nil) // 隐藏弹窗
                        }
                    }
                }
            }
        }
        .frame(width: buttonSize, height: buttonSize)
    }
}

struct AppIconRow: View {
    let appName: String
    let isSelected: Bool  // 新增：选中状态
    var onTooltip: ((ContentView.GlobalTooltipData?) -> Void)? = nil
    var sidebarWidth: CGFloat = 50
    let action: () -> Void
    @State private var isHovered: Bool = false
    @State private var showTooltip: Bool = false
    
    // 固定按钮和图标尺寸
    private let buttonSize: CGFloat = 22
    private let iconSize: CGFloat = 14
    
    private var imageName: String {
        // 简单映射，后续可替换为 Assets 自定义图标
        switch appName {
        case "Google Chrome", "Chrome": return "globe"
        case "Safari": return "safari"
        case "Xcode": return "xcode"
        case "Notes": return "note.text"
        case "Mail": return "envelope"
        case "Finder": return "folder"
        default: return "app"
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Button(action: action) {
                    // 尝试获取真实应用图标，失败则使用系统图标
                    if let appIcon = AppIconHelper.shared.getAppIcon(for: appName) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(
                                isSelected ? SidebarView.selectedBackgroundColor :
                                (isHovered ? Color(red: 0.25, green: 0.25, blue: 0.25) : Color.clear)
                            )
                            .cornerRadius(5)
                    } else {
                        // 备用系统图标
                        Image(systemName: imageName)
                            .foregroundColor(isSelected ? .blue : (isHovered ? .white : .gray))
                            .frame(width: iconSize, height: iconSize)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(
                                isSelected ? SidebarView.selectedBackgroundColor :
                                (isHovered ? Color(red: 0.25, green: 0.25, blue: 0.25) : Color.clear)
                            )
                            .cornerRadius(5)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                    
                    if hovering {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if isHovered {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showTooltip = true
                                    // 使用全局弹窗回调 - 根据实际菜单项位置计算
                                    let localFrame = geometry.frame(in: .named("ContentView"))
                                    onTooltip?(ContentView.GlobalTooltipData.createForMenuItem(
                                        text: appName,
                                        shortcut: nil,
                                        itemFrame: localFrame,
                                        sidebarWidth: sidebarWidth
                                    ))
                                }
                            }
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showTooltip = false
                            onTooltip?(nil) // 隐藏弹窗
                        }
                    }
                }
            }
        }
        .frame(width: buttonSize, height: buttonSize)
    }
}

struct CategoryRow: View {
    let category: ClipboardCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .foregroundColor(isSelected ? .blue : .gray)
                    .frame(width: 20, height: 20)
                
                Text(category.rawValue)
                    .foregroundColor(isSelected ? .white : .gray)
                    .font(.system(size: 14))
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? SidebarView.selectedBackgroundColor : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .help("\(category.rawValue)")
    }
}

struct CompactBottomControlBar: View {
    var body: some View {
        VStack(spacing: 10) {
            // 导航按钮组
            VStack(spacing: 6) {
                Button(action: {}) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add new item")
                
                Button(action: {}) {
                    Image(systemName: "chevron.up")
                        .foregroundColor(.gray)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Navigate up")
                
                Button(action: {}) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Navigate down")
            }
            
            // Feishu Helper按钮
            Button(action: {}) {
                Image(systemName: "link")
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .padding(6)
                    .background(SidebarView.buttonBackgroundColor)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Paste to Feishu Helper")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(SidebarView.backgroundColor)
    }
}

struct BottomControlBar: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {}) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add new item")
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "chevron.up")
                            .foregroundColor(.gray)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Navigate up")
                    
                    Button(action: {}) {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Navigate down")
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.gray)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Navigate")
            }
            
            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                    
                    Text("Paste to Feishu Helper")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(SidebarView.buttonBackgroundColor)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Paste to Feishu Helper")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SidebarView.backgroundColor)
    }
}

#Preview {
    SidebarView(
        clipboardManager: ClipboardManager(),
        selectedCategory: .constant(.history),
        selectedApp: .constant(nil),  // 添加新的必需参数
        onTooltip: { _ in },
        sidebarWidth: 50
    )
}


