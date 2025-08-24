import SwiftUI
import AppKit

// 自定义 NSSplitView 子类，用于自定义分割线颜色
class CustomNSSplitView: NSSplitView {
    override var dividerColor: NSColor {
        return NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 0.3)
    }
    
    override var dividerThickness: CGFloat {
        return 0.5
    }
}

// NSViewRepresentable 包装器
struct CustomSplitView<Content1: View, Content2: View>: NSViewRepresentable {
    let content1: Content1
    let content2: Content2
    
    init(@ViewBuilder content1: () -> Content1, @ViewBuilder content2: () -> Content2) {
        self.content1 = content1()
        self.content2 = content2()
    }
    
    func makeNSView(context: Context) -> CustomNSSplitView {
        let splitView = CustomNSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        
        // 创建 NSHostingView 来包装 SwiftUI 视图
        let hostingView1 = NSHostingView(rootView: content1)
        let hostingView2 = NSHostingView(rootView: content2)
        
        splitView.addSubview(hostingView1)
        splitView.addSubview(hostingView2)
        
        // 设置初始 50:50 分割比例
        // 需要在下一个运行循环中设置，确保布局完成
        DispatchQueue.main.async {
            let totalWidth = splitView.frame.width
            if totalWidth > 0 {
                let halfWidth = totalWidth * 0.5
                splitView.setPosition(halfWidth, ofDividerAt: 0)
                // 根据搜索结果，有时需要调用两次
                splitView.setPosition(halfWidth, ofDividerAt: 0)
            }
        }
        
        return splitView
    }
    
    func updateNSView(_ nsView: CustomNSSplitView, context: Context) {
        // 恢复手动更新逻辑，确保 DetailView 能接收到 selectedItem 状态变化
        if nsView.subviews.count >= 2 {
            // 只更新右侧的 DetailView（content2），避免不必要的左侧列表重建
            if let hostingView2 = nsView.subviews[1] as? NSHostingView<Content2> {
                hostingView2.rootView = content2
            }
        }
    }
}