//
//  ClipBoardApp.swift
//  ClipBoard
//
//  Created by 汪梓文 on 2025/8/11.
//

import SwiftUI
import AppKit
import Carbon

// 通知名称定义
extension Notification.Name {
    static let navigateUp = Notification.Name("clipboard.navigateUp")
    static let navigateDown = Notification.Name("clipboard.navigateDown")
    static let selectCurrentItem = Notification.Name("clipboard.selectCurrentItem")
    static let selectItemByNumber = Notification.Name("clipboard.selectItemByNumber")
    static let resetSelection = Notification.Name("clipboard.resetSelection")
    static let textInputCommand = Notification.Name("clipboard.textInputCommand")
    static let copyCurrentItem = Notification.Name("clipboard.copyCurrentItem")
    static let categoryChanged = Notification.Name("clipboard.categoryChanged")
}

// 自定义窗口类，允许无边框窗口接收键盘输入
class KeyboardAccessibleWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

@main
struct ClipBoardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let windowManager = WindowManager.shared
    
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 首先设置激活策略，确保应用不显示在 Dock 中
        NSApp.setActivationPolicy(.accessory)
        
        // 创建状态栏图标
        setupStatusBar()
        
        // 委托窗口管理给 WindowManager
        Task { @MainActor in
            windowManager.setupMainWindow()
            windowManager.setupEventMonitor()
            windowManager.setupGlobalKeyboardEventMonitor()
            windowManager.setupGlobalHotkeys()
        }
        
        // 检查辅助功能权限
        checkAccessibilityPermissions()
        
        // 设置快捷键处理器
        setupShortcutHandlers()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipBoard")
            button.action = #selector(toggleWindow)
            button.target = self
        }
        
        // 不设置菜单，只响应点击事件
        // statusItem?.menu = nil (默认就是 nil)
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    @objc private func toggleWindow() {
        Task { @MainActor in
            windowManager.toggleWindow()
        }
    }
    
    
    
    
    
    
    // 检查辅助功能权限
    private func checkAccessibilityPermissions() {
        let trusted = AXIsProcessTrusted()
        
        if !trusted {
            print("⚠️ 需要辅助功能权限才能使用全局快捷键")
            
            // 提示用户授权辅助功能权限
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "ClipBoard需要辅助功能权限来响应全局快捷键。请在系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能中添加ClipBoard。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统偏好设置")
            alert.addButton(withTitle: "稍后设置")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // 打开系统偏好设置的辅助功能页面
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        } else {
            print("✅ 辅助功能权限已授权")
        }
    }
    
    @objc private func quitApp() {
        Task { @MainActor in
            windowManager.cleanup()
        }
        NSApp.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            windowManager.cleanup()
        }
    }
    
    
    
    
    // MARK: - 快捷键设置
    
    // 设置所有快捷键处理器
    private func setupShortcutHandlers() {
        let shortcutManager = KeyboardShortcutManager.shared
        
        print("🔧 开始注册快捷键处理器...")
        
        // 分类切换快捷键
        shortcutManager.registerHandler(for: .selectHistory) {
            print("🔥 快捷键⌘1被触发 - 切换到History")
            DispatchQueue.main.async {
                // 通过通知系统更新ContentView的selectedCategory
                NotificationCenter.default.post(name: .categoryChanged, object: ClipboardCategory.history)
            }
        }
        
        shortcutManager.registerHandler(for: .selectFavorites) {
            print("🔥 快捷键⌘2被触发 - 切换到Favorites")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .categoryChanged, object: ClipboardCategory.favorites)
            }
        }
        
        shortcutManager.registerHandler(for: .selectText) {
            print("🔥 快捷键⌘3被触发 - 切换到Text")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .categoryChanged, object: ClipboardCategory.text)
            }
        }
        
        shortcutManager.registerHandler(for: .selectImages) {
            print("🔥 快捷键⌘4被触发 - 切换到Images")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .categoryChanged, object: ClipboardCategory.images)
            }
        }
        
        shortcutManager.registerHandler(for: .selectLinks) {
            print("🔥 快捷键⌘5被触发 - 切换到Links")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .categoryChanged, object: ClipboardCategory.links)
            }
        }
        
        shortcutManager.registerHandler(for: .selectFiles) {
            print("🔥 快捷键⌘6被触发 - 切换到Files")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .categoryChanged, object: ClipboardCategory.files)
            }
        }
        
        shortcutManager.registerHandler(for: .selectMail) {
            print("🔥 快捷键⌘7被触发 - 切换到Mail")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .categoryChanged, object: ClipboardCategory.mail)
            }
        }
        
        // 基本导航快捷键
        shortcutManager.registerHandler(for: .selectItem) {
            print("   ⏎ Enter键 - 选择当前项")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .selectCurrentItem, object: nil)
            }
        }
        
        // ESC键处理已由InputManager的智能逻辑处理（三层：清除搜索→取消焦点→关闭窗口）
        
        shortcutManager.registerHandler(for: .navigateUp) {
            print("   ⬆️ 上箭头 - 向上导航")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .navigateUp, object: nil)
            }
        }
        
        shortcutManager.registerHandler(for: .navigateDown) {
            print("   ⬇️ 下箭头 - 向下导航")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .navigateDown, object: nil)
            }
        }
        
        // 数字键快速选择
        shortcutManager.registerHandler(for: .selectItem1) { self.handleNumberSelection(1) }
        shortcutManager.registerHandler(for: .selectItem2) { self.handleNumberSelection(2) }
        shortcutManager.registerHandler(for: .selectItem3) { self.handleNumberSelection(3) }
        shortcutManager.registerHandler(for: .selectItem4) { self.handleNumberSelection(4) }
        shortcutManager.registerHandler(for: .selectItem5) { self.handleNumberSelection(5) }
        shortcutManager.registerHandler(for: .selectItem6) { self.handleNumberSelection(6) }
        shortcutManager.registerHandler(for: .selectItem7) { self.handleNumberSelection(7) }
        shortcutManager.registerHandler(for: .selectItem8) { self.handleNumberSelection(8) }
        shortcutManager.registerHandler(for: .selectItem9) { self.handleNumberSelection(9) }
        
        // 功能快捷键
        shortcutManager.registerHandler(for: .copyItem) {
            print("   📝 Cmd+C - 复制当前项")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .copyCurrentItem, object: nil)
            }
        }
        
        // 窗口控制快捷键已由ESC键(clearSearchOrClose)处理
        
        print("✅ 快捷键处理器注册完成")
    }
    
    // 处理数字键选择的辅助方法
    private func handleNumberSelection(_ number: Int) {
        print("   🔢 数字键\(number) - 快速选择")
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .selectItemByNumber, object: number)
        }
    }
    
    // MARK: - 调试辅助方法
    
    
}

