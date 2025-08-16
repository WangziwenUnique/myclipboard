//
//  ClipBoardApp.swift
//  ClipBoard
//
//  Created by 汪梓文 on 2025/8/11.
//

import SwiftUI
import AppKit
import Carbon

// 自定义窗口类，允许无边框窗口接收键盘输入
class KeyboardAccessibleWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
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
    private var popover: NSPopover?
    private var window: NSWindow?
    private var eventMonitor: Any?
    private var keyEventMonitor: Any?
    private var shortcutManager = KeyboardShortcutManager.shared
    private var globalHotKeyRef: EventHotKeyRef?
    
    // 用于保存窗口大小的 UserDefaults keys
    private let windowWidthKey = "ClipBoard.WindowWidth"
    private let windowHeightKey = "ClipBoard.WindowHeight"
    
    // 用于跟踪前一个激活应用
    private var previousApp: NSRunningApplication?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 首先设置激活策略，确保应用不显示在 Dock 中
        NSApp.setActivationPolicy(.accessory)
        
        // 创建状态栏图标
        setupStatusBar()
        
        // 创建主窗口但不显示
        setupMainWindow()
        
        // 设置全局事件监听器，用于检测窗口失去焦点
        setupEventMonitor()
        
        // 设置键盘事件监听器
        setupKeyboardEventMonitor()
        
        // 设置全局快捷键
        setupGlobalHotkeys()
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
    
    private func setupMainWindow() {
        // 创建主容器视图
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.layer?.cornerRadius = 12.0
        containerView.layer?.masksToBounds = true
        
        // 创建内容视图
        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)
        
        // 设置内容视图填满整个容器
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        hostingController.view.layer?.cornerRadius = 12.0
        hostingController.view.layer?.masksToBounds = true
        
        // 添加高光边框作为装饰层
        hostingController.view.layer?.borderWidth = 0.5
        hostingController.view.layer?.borderColor = NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 0.3).cgColor
        
        // 将内容视图添加到容器视图中，填满整个空间
        containerView.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置约束，让内容视图填满整个容器
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // 恢复上次保存的窗口大小，或使用默认值
        let savedWidth = UserDefaults.standard.object(forKey: windowWidthKey) as? CGFloat ?? 820
        let savedHeight = UserDefaults.standard.object(forKey: windowHeightKey) as? CGFloat ?? 540
        
        window = KeyboardAccessibleWindow(
            contentRect: NSRect(x: 0, y: 0, width: savedWidth, height: savedHeight),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window?.title = "ClipBoard"
        window?.contentView = containerView
        
        // 设置窗口在屏幕中心
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window?.frame ?? NSRect(x: 0, y: 0, width: 820, height: 540)
            
            let centerX = screenFrame.midX - windowFrame.width / 2
            let centerY = screenFrame.midY - windowFrame.height / 2
            
            let windowOrigin = NSPoint(x: centerX, y: centerY)
            window?.setFrameOrigin(windowOrigin)
        } else {
            window?.center()
        }
        
        window?.isReleasedWhenClosed = false
        window?.delegate = self
        
        // 设置窗口行为，确保不显示在 Dock 中，但允许键盘输入
        window?.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        window?.level = .floating
        
        // 注意：canBecomeKey 是只读属性，通过设置窗口样式来确保可以接收键盘输入
        
        // 设置无边框窗口的额外属性
        window?.backgroundColor = NSColor.clear
        window?.isOpaque = false
        window?.hasShadow = true
        
        // 确保窗口背景透明，这样圆角效果才能正确显示
        window?.contentView?.wantsLayer = true
        window?.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        // 设置圆角效果 - 通过设置窗口的 layer 来实现
        window?.isMovableByWindowBackground = true
        
        // 确保窗口可以响应鼠标事件进行拖动
        window?.acceptsMouseMovedEvents = true
        
        // 设置合理的窗口大小限制，允许用户调整
        window?.minSize = NSSize(width: 720, height: 480)
        window?.maxSize = NSSize(width: 1600, height: 1200)
        
        // 启用窗口的 layer 支持并设置圆角
        // 注意：这些属性应该设置在 contentView 上，而不是 window 上
        
        // 确保窗口初始状态为隐藏
        window?.orderOut(nil)
    }
    
    private func setupEventMonitor() {
        // 监听全局鼠标点击事件，当点击窗口外部时立即自动关闭窗口
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let window = self?.window, window.isVisible {
                // 获取全局鼠标位置
                let globalLocation = NSEvent.mouseLocation
                let windowFrame = window.frame
                
                // 检查点击是否在窗口外部
                if !windowFrame.contains(globalLocation) {
                    // 检查是否点击在状态栏按钮上，如果是则不关闭窗口
                    if let statusButton = self?.statusItem?.button,
                       let statusWindow = statusButton.window {
                        let buttonRect = statusButton.convert(statusButton.bounds, to: nil)
                        let screenButtonRect = statusWindow.convertToScreen(buttonRect)
                        
                        if !screenButtonRect.contains(globalLocation) {
                            // 立即关闭窗口，不添加延迟
                            self?.hideWindow()
                        }
                    } else {
                        // 立即关闭窗口，不添加延迟
                        self?.hideWindow()
                    }
                }
            }
        }
    }
    
    private func setupKeyboardEventMonitor() {
        // 监听本地键盘事件（当窗口有焦点时）
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, let window = self.window, window.isVisible else { return event }
            
            let keyEquivalent = event.charactersIgnoringModifiers ?? ""
            let modifiers = self.convertNSModifiersToEventModifiers(event.modifierFlags)
            
            // 让快捷键管理器处理事件
            if self.shortcutManager.handleKeyEvent(keyEquivalent: keyEquivalent, modifiers: modifiers) {
                return nil // 消费该事件
            }
            
            return event // 不处理，继续传递
        }
    }
    
    private func convertNSModifiersToEventModifiers(_ nsModifiers: NSEvent.ModifierFlags) -> SwiftUI.EventModifiers {
        var modifiers: SwiftUI.EventModifiers = []
        
        if nsModifiers.contains(.command) {
            modifiers.insert(.command)
        }
        if nsModifiers.contains(.shift) {
            modifiers.insert(.shift)
        }
        if nsModifiers.contains(.option) {
            modifiers.insert(.option)
        }
        if nsModifiers.contains(.control) {
            modifiers.insert(.control)
        }
        
        return modifiers
    }
    
    private func setupGlobalHotkeys() {
        // 注册全局快捷键 Shift+Cmd+V
        registerGlobalHotKey()
    }
    
    private func registerGlobalHotKey() {
        let hotKeyId = EventHotKeyID(signature: OSType(0x53484356), id: 1) // 'SHCV' for Shift+Cmd+V
        let modifiers = UInt32(shiftKey | cmdKey)
        let keyCode = UInt32(9) // V key
        
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        // 安装事件处理器
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            
            var hotKeyId = EventHotKeyID()
            GetEventParameter(theEvent, OSType(kEventParamDirectObject), OSType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyId)
            
            if hotKeyId.signature == OSType(0x53484356) && hotKeyId.id == 1 {
                DispatchQueue.main.async {
                    appDelegate.handleGlobalHotKey()
                }
            }
            
            return noErr
        }, 1, &eventSpec, selfPtr, nil)
        
        // 注册热键
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyId, GetApplicationEventTarget(), 0, &globalHotKeyRef)
        
        if status != noErr {
            print("Failed to register global hotkey with status: \(status)")
        } else {
            print("Successfully registered global hotkey Shift+Cmd+V")
        }
    }
    
    private func handleGlobalHotKey() {
        // 处理全局快捷键 Shift+Cmd+V
        if let window = window {
            if window.isVisible {
                hideWindow()
            } else {
                showMainWindow()
            }
        }
    }
    
    private func unregisterGlobalHotKey() {
        if let hotKeyRef = globalHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            globalHotKeyRef = nil
        }
    }
    
    @objc private func toggleWindow() {
        if let window = window {
            if window.isVisible {
                hideWindow()
            } else {
                showMainWindow()
            }
        }
    }
    
    @objc private func showMainWindow() {
        if let window = window {
            // 记录当前激活的应用（显示窗口前）
            previousApp = NSWorkspace.shared.frontmostApplication
            
            // 获取主屏幕
            if let screen = NSScreen.main {
                // 计算屏幕中心位置
                let screenFrame = screen.visibleFrame
                let windowFrame = window.frame
                
                // 计算窗口在屏幕中心的坐标
                let centerX = screenFrame.midX - windowFrame.width / 2
                let centerY = screenFrame.midY - windowFrame.height / 2
                
                // 设置窗口位置在屏幕中心
                let windowOrigin = NSPoint(x: centerX, y: centerY)
                window.setFrameOrigin(windowOrigin)
            } else {
                // 如果没有主屏幕，使用默认的居中方法
                window.center()
            }

            // 激活应用以确保窗口能够响应键盘输入
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            
            // 确保窗口能够接收键盘输入
            window.makeFirstResponder(window.contentView)
        }
    }
    
    @objc private func hideWindow() {
        if let window = window {
            window.orderOut(nil)
        }
    }
    
    // 恢复前一个应用的激活状态并执行粘贴
    func restorePreviousAppAndPaste() {
        guard let previousApp = previousApp else { 
            // 如果没有记录前一个应用，只关闭窗口
            hideWindow()
            return 
        }
        
        // 检查前一个应用是否仍在运行
        guard previousApp.isActive || NSWorkspace.shared.runningApplications.contains(previousApp) else {
            // 如果前一个应用已关闭，只关闭窗口
            hideWindow()
            return
        }
        
        // 先隐藏当前窗口
        hideWindow()
        
        // 延迟确保窗口完全隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 激活前一个应用
            let activated = previousApp.activate(options: [])
            
            if activated {
                // 延迟确保应用切换完成，然后执行粘贴
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.simulatePasteCommand()
                }
            } else {
                print("Failed to activate previous app: \(previousApp.bundleIdentifier ?? "unknown")")
            }
        }
    }
    
    // 模拟 Command+V 粘贴操作
    private func simulatePasteCommand() {
        // 创建 Command+V 按键事件
        let source = CGEventSource(stateID: .hidSystemState)
        
        // 按下 Command 键
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) // 0x37 是 Command 键
        cmdDown?.flags = .maskCommand
        
        // 按下 V 键
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 是 V 键
        vDown?.flags = .maskCommand
        
        // 释放 V 键
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        
        // 释放 Command 键
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        // 发送事件序列
        let location = CGEventTapLocation.cghidEventTap
        cmdDown?.post(tap: location)
        vDown?.post(tap: location)
        vUp?.post(tap: location)
        cmdUp?.post(tap: location)
    }
    
    @objc private func quitApp() {
        // 清理事件监听器
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        if let keyEventMonitor = keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
        }
        // 清理全局快捷键
        unregisterGlobalHotKey()
        NSApp.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 应用即将退出时清理资源
        unregisterGlobalHotKey()
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideWindow()
        return false
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // 窗口失去焦点时立即自动关闭
        if let window = window, window.isVisible {
            self.hideWindow()
        }
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // 窗口获得焦点时的处理（可选）
    }
    
    func windowWillClose(_ notification: Notification) {
        // 窗口关闭时的处理
    }
    
    func windowDidResize(_ notification: Notification) {
        // 窗口大小改变时保存新的尺寸
        if let window = window {
            let size = window.frame.size
            UserDefaults.standard.set(size.width, forKey: windowWidthKey)
            UserDefaults.standard.set(size.height, forKey: windowHeightKey)
        }
    }
}
