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
    @State private var selectedCategory: ClipboardCategory = .history
    @State private var selectedApp: String? = nil  // 新增：选中的应用筛选
    @State private var globalTooltip: GlobalTooltipData? = nil
    @State private var isSidebarVisible: Bool = true
    @State private var isWindowPinned: Bool = false
    
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
                            sidebarWidth: geometry.size.width * 0.06
                        )
                        .frame(width: geometry.size.width * 0.06, height: geometry.size.height)
                        .background(Color.clear) // 确保背景透明以便弹窗显示
                        .transition(.move(edge: .leading))
                    
                        // 分割线 1
                        Rectangle()
                            .fill(Color(red: 0.7, green: 0.7, blue: 0.7, opacity: 0.3))
                            .frame(width: 0.5, height: geometry.size.height)
                    }
                
                    // 中间列表视图 - 动态调整宽度
                    let listWidth = isSidebarVisible ? 
                        (geometry.size.width * 0.94) / 2 - 1 : 
                        geometry.size.width / 2 - 0.25
                    
                    ClipboardListView(
                        clipboardManager: clipboardManager,
                        selectedItem: $clipboardManager.selectedItem,
                        category: selectedCategory,
                        selectedApp: selectedApp,  // 传递应用筛选状态
                        isSidebarVisible: $isSidebarVisible,
                        isWindowPinned: $isWindowPinned
                    )
                    .frame(width: listWidth, height: geometry.size.height)
                    
                    // 分割线 2
                    Rectangle()
                        .fill(Color(red: 0.7, green: 0.7, blue: 0.7, opacity: 0.3))
                        .frame(width: 0.5, height: geometry.size.height)
                    
                    // 右侧详情视图 - 动态调整宽度
                    let detailWidth = isSidebarVisible ? 
                        (geometry.size.width * 0.94) / 2 - 1 : 
                        geometry.size.width / 2 - 0.25
                    
                    DetailView(
                        clipboardManager: clipboardManager,
                        selectedItem: clipboardManager.selectedItem
                    )
                    .frame(width: detailWidth, height: geometry.size.height)
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
        .frame(minWidth: 820, minHeight: 540)
        .background(SidebarView.backgroundColor)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
