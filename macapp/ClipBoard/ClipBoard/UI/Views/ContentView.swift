//
//  ContentView.swift
//  ClipBoard
//
//  Created by 汪梓文 on 2025/8/11.
//

import SwiftUI
import CoreData


struct ContentView: View {
    @StateObject private var clipboardManager = ClipboardManager()
    @ObservedObject private var shortcutManager = KeyboardShortcutManager.shared
    @State private var selectedCategory: ClipboardCategory = .history
    @State private var selectedApp: String? = nil  // 新增：选中的应用筛选
    @State private var selectedItem: ClipboardItem? = nil  // 移到ContentView管理
    @State private var globalTooltip: GlobalTooltipData? = nil
    @State private var isSidebarVisible: Bool = true
    @State private var isWindowPinned: Bool = false
    
    // 观察者引用，用于内存清理
    @State private var observers: [NSObjectProtocol] = []
    
    struct GlobalTooltipData {
        let text: String
        let shortcut: String?
        let position: CGPoint
        
        // 便利构造函数，根据菜单项的实际位置计算弹窗位置（真正的左对齐）
        static func createForMenuItem(text: String, shortcut: String?, itemFrame: CGRect, sidebarWidth: CGFloat) -> GlobalTooltipData {
            return GlobalTooltipData(
                text: text,
                shortcut: shortcut,
                position: CGPoint(
                    x: itemFrame.maxX + 6,  // 固定的左边缘位置：菜单项右侧 + 6px（更贴近菜单项）
                    y: itemFrame.midY        // 菜单项的垂直中心位置
                )
            )
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    // 左侧边栏 - 可隐藏
                    if isSidebarVisible {
                        SidebarView(
                            clipboardManager: clipboardManager, 
                            selectedCategory: $selectedCategory,
                            selectedApp: $selectedApp,  // 传递应用筛选状态
                            onTooltip: { tooltipData in
                                globalTooltip = tooltipData
                            },
                            sidebarWidth: 50.0
                        )
                        .frame(width: 50, height: geometry.size.height)
                        .background(Color.clear) // 确保背景透明以便弹窗显示
                        .transition(.move(edge: .leading))
                    
                        // 分割线 1
                        Rectangle()
                            .fill(Color(red: 0.7, green: 0.7, blue: 0.7, opacity: 0.3))
                            .frame(width: 0.5)
                    }
                
                    // 主内容区域 - 使用HSplitView实现可拖拽分割线
                    let sidebarActualWidth: CGFloat = isSidebarVisible ? 50.5 : 0 // 50 + 0.5 for Rectangle
                    let mainContentWidth = geometry.size.width - sidebarActualWidth
                    
                    CustomSplitView {
                        ClipboardListView(
                            clipboardManager: clipboardManager,
                            selectedItem: $selectedItem,
                            category: $selectedCategory,
                            selectedApp: selectedApp,
                            isSidebarVisible: $isSidebarVisible,
                            isWindowPinned: $isWindowPinned,
                            shortcutManager: shortcutManager
                        )
                    } content2: {
                        DetailView(
                            clipboardManager: clipboardManager,
                            selectedItem: selectedItem
                        )
                    }
                    .frame(width: mainContentWidth, height: geometry.size.height)
                }
                
                // 全局弹窗层 - 使用HStack实现真正的左边缘对齐
                if let tooltip = globalTooltip {
                    VStack {
                        Spacer()
                            .frame(height: tooltip.position.y - 14) // 垂直定位，减去弹窗高度的一半
                        
                        HStack {
                            Spacer()
                                .frame(width: tooltip.position.x) // 水平定位到左边缘位置
                            
                            CustomTooltip(text: tooltip.text, shortcut: tooltip.shortcut)
                            
                            Spacer() // 右侧自由空间
                        }
                        
                        Spacer() // 底部自由空间
                    }
                    .allowsHitTesting(false)
                    .zIndex(1000)
                }
            }
            .coordinateSpace(name: "ContentView")
        }
        .background(SidebarView.backgroundColor)
        .preferredColorScheme(.dark)
        .onAppear {
            setupKeyboardShortcuts()
            setupNotificationObservers()
            // 配置InputManager单例
            InputManager.configure(clipboardManager: clipboardManager)
        }
        .onDisappear {
            cleanupObservers()
        }
        .onChange(of: selectedCategory) { oldValue, newValue in
            print("🎯 ContentView selectedCategory onChange: \(oldValue) → \(newValue)")
        }
    }
    
    // MARK: - 快捷键设置（仅窗口控制）
    private func setupKeyboardShortcuts() {
        // 窗口控制快捷键（UI层面的状态）
        shortcutManager.registerHandler(for: .toggleSidebar) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSidebarVisible.toggle()
            }
        }
        
        shortcutManager.registerHandler(for: .toggleWindowPin) {
            isWindowPinned.toggle()
            // 这里可以添加窗口置顶的逻辑
        }
    }
    
    // MARK: - 通知监听
    private func setupNotificationObservers() {
        // 先清理已有观察者
        cleanupObservers()
        
        // 监听分类切换通知
        let categoryObserver = NotificationCenter.default.addObserver(
            forName: .categoryChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let category = notification.object as? ClipboardCategory {
                print("📱 收到分类切换通知: \(category)")
                selectedCategory = category
                selectedApp = nil // 切换分类时清除应用筛选
            }
        }
        
        // 监听剪贴板监控切换通知
        let monitoringObserver = NotificationCenter.default.addObserver(
            forName: .toggleClipboardMonitoring,
            object: nil,
            queue: .main
        ) { [weak clipboardManager] _ in
            clipboardManager?.toggleMonitoring()
        }
        
        observers.append(categoryObserver)
        observers.append(monitoringObserver)
    }
    
    // MARK: - 观察者清理
    private func cleanupObservers() {
        let count = observers.count
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        if count > 0 {
            print("🧹 ContentView 清理了 \(count) 个通知观察者")
        }
    }
}

#Preview {
    ContentView()
}
