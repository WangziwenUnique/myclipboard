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
    @State private var globalTooltip: GlobalTooltipData? = nil
    
    struct GlobalTooltipData {
        let text: String
        let shortcut: String?
        let position: CGPoint
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    // 左侧边栏 - 缩小为总宽度的 6%
                    SidebarView(
                        clipboardManager: clipboardManager, 
                        selectedCategory: $selectedCategory,
                        onTooltip: { tooltipData in
                            globalTooltip = tooltipData
                        }
                    )
                    .frame(width: geometry.size.width * 0.06, height: geometry.size.height)
                    .background(Color.clear) // 确保背景透明以便弹窗显示
                
                // 分割线 1
                Rectangle()
                    .fill(Color(red: 0.7, green: 0.7, blue: 0.7, opacity: 0.3))
                    .frame(width: 0.5, height: geometry.size.height)
                
                // 中间列表视图 - 占总宽度的 39.5%（将左栏缩小的比例加到这里）
                ClipboardListView(
                    clipboardManager: clipboardManager,
                    selectedItem: $clipboardManager.selectedItem,
                    category: selectedCategory
                )
                .frame(width: geometry.size.width * 0.395 - 1, height: geometry.size.height)
                
                // 分割线 2
                Rectangle()
                    .fill(Color(red: 0.7, green: 0.7, blue: 0.7, opacity: 0.3))
                    .frame(width: 0.5, height: geometry.size.height)
                
                // 右侧详情视图 - 占总宽度的 54.5%
                DetailView(
                    clipboardManager: clipboardManager,
                    selectedItem: clipboardManager.selectedItem
                )
                .frame(width: geometry.size.width * 0.545 - 1, height: geometry.size.height)
                }
                
                // 全局弹窗层 - 显示在最顶层
                if let tooltip = globalTooltip {
                    CustomTooltip(text: tooltip.text, shortcut: tooltip.shortcut)
                        .position(tooltip.position)
                        .allowsHitTesting(false)
                        .zIndex(1000)
                }
            }
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
