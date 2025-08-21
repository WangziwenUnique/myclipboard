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
    static let toggleClipboardMonitoring = Notification.Name("clipboard.toggleMonitoring")
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
    private var settingsWindowController: SettingsWindowController?
    private var aboutWindowController: AboutWindowController?
    private var contextMenu: NSMenu?
    
    
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
        
        // 监听剪贴板监控状态变化
        setupStatusBarNotifications()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipBoard")
            button.action = #selector(toggleWindow)
            button.target = self
            
            // 只响应左键点击
            button.sendAction(on: [.leftMouseUp])
            
            // 添加右键事件监听
            setupRightClickMonitoring()
        }
        
        // 创建菜单但不直接设置给状态栏项
        setupStatusBarMenu()
    }
    
    private func setupStatusBarMenu() {
        let menu = NSMenu()
        
        // Open ClipBook
        let openItem = NSMenuItem(title: "Open ClipBook", action: #selector(toggleWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Help 子菜单
        let helpItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        let helpSubmenu = NSMenu()
        let helpContentsItem = NSMenuItem(title: "ClipBook Help", action: #selector(showHelp), keyEquivalent: "")
        helpContentsItem.target = self
        helpSubmenu.addItem(helpContentsItem)
        helpItem.submenu = helpSubmenu
        menu.addItem(helpItem)
        
        // About ClipBook
        let aboutItem = NSMenuItem(title: "About ClipBook", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        // Check for Updates...
        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)
        
        // Settings... (⌘,)
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Pause ClipBook - 根据当前状态设置初始标题
        let isMonitoring = UserDefaults.standard.object(forKey: "clipboardMonitoring") == nil ? true : UserDefaults.standard.bool(forKey: "clipboardMonitoring")
        let pauseItem = NSMenuItem(title: isMonitoring ? "Pause ClipBook" : "Resume ClipBook", action: #selector(toggleClipboardMonitoring), keyEquivalent: "")
        pauseItem.target = self
        pauseItem.tag = 100 // 用于动态更新标题
        menu.addItem(pauseItem)
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // 保存菜单引用，但不直接设置给状态栏项
        contextMenu = menu
    }
    
    private func setupRightClickMonitoring() {
        guard let button = statusItem?.button else { return }
        
        // 监听右键点击事件
        NSEvent.addLocalMonitorForEvents(matching: [.rightMouseUp]) { [weak self] event in
            guard let self = self else { return event }
            
            // 检查点击是否在状态栏按钮区域内
            let windowPoint = event.locationInWindow
            let buttonFrame = button.frame
            
            if button.window == event.window && buttonFrame.contains(windowPoint) {
                self.showContextMenu()
                return nil // 消费这个事件
            }
            
            return event
        }
    }
    
    private func showContextMenu() {
        guard let menu = contextMenu, let button = statusItem?.button else { return }
        
        // 在状态栏按钮位置显示菜单
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.frame.height), in: button)
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
    
    // MARK: - 菜单项 Actions
    
    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(self)
    }
    
    @objc private func showAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.showWindow(self)
    }
    
    @objc private func showHelp() {
        // 打开帮助网页或显示帮助信息
        if let url = URL(string: "https://github.com/your-repo/clipbook/help") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func checkForUpdates() {
        // 这里可以实现更新检查逻辑
        let alert = NSAlert()
        alert.messageText = "Check for Updates"
        alert.informativeText = "Update checking feature will be implemented in a future version."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func toggleClipboardMonitoring() {
        // 获取全局的 ClipboardManager 实例
        // 注意：这里需要一个方式来访问全局的 ClipboardManager 实例
        // 为了简化，我们先使用通知机制
        NotificationCenter.default.post(name: .toggleClipboardMonitoring, object: nil)
    }
    
    // MARK: - 状态栏通知监听
    
    private func setupStatusBarNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuItemTitles),
            name: .toggleClipboardMonitoring,
            object: nil
        )
    }
    
    @objc private func updateMenuItemTitles() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // 获取当前监控状态
            let isMonitoring = UserDefaults.standard.object(forKey: "clipboardMonitoring") == nil ? true : UserDefaults.standard.bool(forKey: "clipboardMonitoring")
            
            // 更新菜单项标题
            if let menu = self?.contextMenu,
               let pauseItem = menu.item(withTag: 100) {
                pauseItem.title = isMonitoring ? "Pause ClipBook" : "Resume ClipBoard"
            }
        }
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

