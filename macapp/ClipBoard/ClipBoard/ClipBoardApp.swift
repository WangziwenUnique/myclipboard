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
    static let updateSearchText = Notification.Name("clipboard.updateSearchText")
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
    private var popover: NSPopover?
    private var window: NSWindow?
    private var eventMonitor: Any?
    private var eventTap: CFMachPort? // CGEventTap 用于真正拦截键盘事件
    private var shortcutManager = KeyboardShortcutManager.shared
    private var globalHotKeyRef: EventHotKeyRef?
    
    // 防抖机制相关
    private var lastHotKeyTime: Date = Date.distantPast
    private let hotKeyDebounceInterval: TimeInterval = 0.3 // 300ms防抖
    
    // 事件去重相关
    private var lastKeyEvent: (keyCode: UInt16, timestamp: Date) = (0, Date.distantPast)
    private let keyEventDebounceInterval: TimeInterval = 0.1 // 100ms去重
    
    // 用于保存窗口大小的 UserDefaults keys
    private let windowWidthKey = "ClipBoard.WindowWidth"
    private let windowHeightKey = "ClipBoard.WindowHeight"
    
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 首先设置激活策略，确保应用不显示在 Dock 中
        NSApp.setActivationPolicy(.accessory)
        
        // 创建状态栏图标
        setupStatusBar()
        
        // 创建主窗口但不显示
        setupMainWindow()
        
        // 设置全局事件监听器，用于检测窗口失去焦点
        setupEventMonitor()
        
        // 检查辅助功能权限
        checkAccessibilityPermissions()
        
        // 设置全局键盘事件监听器（使用 CGEventTap）
        setupGlobalKeyboardEventMonitor()
        
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
        
        // 设置浮层窗口行为：确保不影响其他应用的激活状态
        window?.collectionBehavior = [.transient, .fullScreenAuxiliary, .stationary]
        // 使用更高的窗口层级确保在全屏应用上方显示
        window?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
        
        // 避免窗口意外获得焦点，完全依赖全局监听器
        window?.hidesOnDeactivate = false
        
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
    
    private func setupGlobalKeyboardEventMonitor() {
        // 检查辅助功能权限
        guard AXIsProcessTrusted() else {
            print("❌ 无辅助功能权限，CGEventTap无法正常工作")
            return
        }
        
        // 创建 CGEventTap 用于真正拦截键盘事件
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        // 创建事件回调
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) in
            // 从 refcon 获取 AppDelegate 实例
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
            
            // 调用实例方法处理事件
            return appDelegate.handleCGKeyEvent(proxy: proxy, type: type, event: event)
        }
        
        // 获取 self 的指针
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        // 创建事件tap
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: selfPtr
        )
        
        guard let eventTap = eventTap else {
            print("❌ CGEventTap 创建失败")
            return
        }
        
        // 创建运行循环源
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        // 添加到当前运行循环
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // 启用事件tap
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        print("✅ CGEventTap 已设置并启用（真正拦截模式）")
    }
    
    // CGEventTap 回调处理方法
    private func handleCGKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 只处理按键按下事件
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        
        // 检查窗口是否可见
        guard let window = window, window.isVisible else {
            // 窗口不可见时，不拦截任何事件
            return Unmanaged.passUnretained(event)
        }
        
        // 获取按键信息
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        print("🎯 [CGEventTap] 检测到按键：keyCode=\(keyCode)")
        
        // 检查是否是剪贴板相关按键
        if isClipboardRelevantKeyCode(keyCode) {
            print("   - ✅ 剪贴板相关按键，拦截处理")
            
            // 转换修饰键
            let modifiers = convertCGModifiersToEventModifiers(flags)
            
            // 处理按键
            let handled = handleKeyCodeDirectly(keyCode, modifiers: modifiers)
            
            if handled {
                print("   - ✅ 按键已处理，消费事件")
                // 返回 nil 表示消费这个事件，不再传播
                return nil
            } else {
                print("   - ❌ 按键未处理，继续传播")
                return Unmanaged.passUnretained(event)
            }
        } else {
            print("   - ➡️ 非剪贴板按键，继续传播")
            // 不是剪贴板相关按键，正常传播
            return Unmanaged.passUnretained(event)
        }
    }
    
    // 基于 keyCode 判断是否是clipboard相关的按键
    private func isClipboardRelevantKeyCode(_ keyCode: UInt16) -> Bool {
        let relevantKeyCodes: [UInt16] = [
            36, 53,           // Enter, Esc
            126, 125, 123, 124, // 方向键（上下左右）
            18, 19, 20, 21, 23, 22, 26, 28, 25, // 数字键 1-9
            // 字母键 A-Z
            0, 1, 2, 3, 5, 4, 6, 7, 8, 9, 11, 45, 46, 43, 47, 44, 12, 13, 14, 15, 17, 16, 32, 34, 35, 31,
            // 输入相关按键
            49, 51,           // Space, Backspace
            48,               // Tab
            27, 24, 33, 30,   // -, =, [, ]
            41, 39, 42,       // ;, ', \
            43, 47, 44,       // ,, /, .
            50,               // `
        ]
        
        return relevantKeyCodes.contains(keyCode)
    }
    
    // 转换 CGEventFlags 到 SwiftUI.EventModifiers
    private func convertCGModifiersToEventModifiers(_ cgFlags: CGEventFlags) -> SwiftUI.EventModifiers {
        var modifiers: SwiftUI.EventModifiers = []
        
        if cgFlags.contains(.maskCommand) {
            modifiers.insert(.command)
        }
        if cgFlags.contains(.maskShift) {
            modifiers.insert(.shift)
        }
        if cgFlags.contains(.maskAlternate) {
            modifiers.insert(.option)
        }
        if cgFlags.contains(.maskControl) {
            modifiers.insert(.control)
        }
        
        return modifiers
    }
    
    // 判断是否是clipboard相关的按键（诊断模式：更宽松的判断）
    private func isClipboardRelevantKey(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        
        print("   🔍 检查按键相关性：keyCode=\(keyCode)")
        
        // 常用导航和操作键（扩大范围用于诊断）
        let relevantKeyCodes: [UInt16] = [
            36, 53,           // Enter, Esc
            126, 125, 123, 124, // 方向键（上下左右）
            18, 19, 20, 21, 23, 22, 26, 28, 25, // 数字键 1-9
            0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, // 字母键
            49, 51,           // Space, Backspace
            48,               // Tab
        ]
        
        let isRelevant = relevantKeyCodes.contains(keyCode)
        print("   🔍 按键\(keyCode)\(isRelevant ? "相关" : "不相关")")
        
        return isRelevant
    }
    
    // 基于keyCode直接处理按键（绕过字符匹配问题）
    private func handleKeyCodeDirectly(_ keyCode: UInt16, modifiers: SwiftUI.EventModifiers) -> Bool {
        print("   🔧 直接处理keyCode=\(keyCode)")
        
        switch keyCode {
        case 36: // Enter
            print("   ⏎ Enter键 - 选择当前项")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .selectCurrentItem, object: nil)
            }
            return true
            
        case 53: // Esc
            print("   ⛔ Esc键 - 关闭窗口")
            DispatchQueue.main.async {
                self.hideWindow()
            }
            return true
            
        case 125: // 下箭头
            print("   ⬇️ 下箭头 - 向下导航")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .navigateDown, object: nil)
            }
            return true
            
        case 126: // 上箭头
            print("   ⬆️ 上箭头 - 向上导航")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .navigateUp, object: nil)
            }
            return true
            
        case 18...26: // 数字键 1-9
            let number = Int(keyCode - 17) // keyCode 18 = 数字1
            print("   🔢 数字键\(number) - 快速选择")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .selectItemByNumber, object: number)
            }
            return true
            
        case 51: // Backspace
            print("   ⌫ 退格键 - 删除字符")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .updateSearchText, object: ["action": "backspace"])
            }
            return true
            
        case 49: // Space
            print("   ␣ 空格键 - 输入空格")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .updateSearchText, object: ["action": "append", "character": " "])
            }
            return true
            
        // 字母键处理
        case 0...31, 32...50: // 字母键和其他可输入字符
            if let character = keyCodeToCharacter(keyCode, modifiers: modifiers) {
                print("   ✏️ 输入字符: '\(character)'")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .updateSearchText, object: ["action": "append", "character": character])
                }
                return true
            }
            return false
            
        default:
            print("   ❓ 未支持的keyCode: \(keyCode)")
            return false
        }
    }
    
    // 将keyCode转换为字符
    private func keyCodeToCharacter(_ keyCode: UInt16, modifiers: SwiftUI.EventModifiers) -> String? {
        // 基础字母键映射 (QWERTY键盘布局)
        let keyMap: [UInt16: String] = [
            // 第一行：Q W E R T Y U I O P
            12: "q", 13: "w", 14: "e", 15: "r", 17: "t", 16: "y", 32: "u", 34: "i", 31: "o", 35: "p",
            // 第二行：A S D F G H J K L
            0: "a", 1: "s", 2: "d", 3: "f", 5: "g", 4: "h", 38: "j", 40: "k", 37: "l",
            // 第三行：Z X C V B N M
            6: "z", 7: "x", 8: "c", 9: "v", 11: "b", 45: "n", 46: "m",
            // 数字键
            29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
            // 符号键
            27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/", 50: "`"
        ]
        
        guard let baseChar = keyMap[keyCode] else {
            return nil
        }
        
        // 处理大写（Shift修饰键）
        if modifiers.contains(.shift) {
            return baseChar.uppercased()
        }
        
        return baseChar
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
                // 直接调用，热键处理器已在主线程运行
                appDelegate.handleGlobalHotKey()
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
        // 防抖机制：避免快速重复触发
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastHotKeyTime) < hotKeyDebounceInterval {
            print("🚫 全局热键防抖：忽略重复调用")
            return
        }
        lastHotKeyTime = currentTime
        
        print("⚡ 处理全局快捷键 Shift+Cmd+V")
        
        // 处理全局快捷键 Shift+Cmd+V
        if let window = window {
            if window.isVisible {
                print("📋 窗口已显示，隐藏窗口")
                hideWindow()
            } else {
                print("📋 窗口未显示，显示窗口")
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
            print("🚀 准备显示主窗口")
            
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

            print("🚀 显示浮层窗口（纯浮层模式）")
            
            // 确保窗口在最高层级
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
            
            // 纯浮层显示：绝不激活应用或改变焦点
            // 使用orderFront而不是makeKeyAndOrderFront，避免获得焦点
            window.orderFront(nil)
            
            // 强制将窗口移到最前端（在所有桌面空间中可见）
            window.orderFrontRegardless()
            
            // 窗口显示后，发送重置选择索引的通知
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("📤 发送重置选择索引通知")
                NotificationCenter.default.post(name: .resetSelection, object: nil)
            }
            
            print("✅ 纯浮层窗口显示完成，依赖全局监听器处理快捷键")
        }
    }
    
    @objc private func hideWindow() {
        if let window = window {
            window.orderOut(nil)
        }
    }
    
    // 直接粘贴到当前激活的应用
    func performDirectPaste() {
        // 先隐藏窗口
        hideWindow()
        
        // 短暂延迟确保窗口隐藏，然后直接粘贴
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.performPasteOperation()
        }
    }
    
    // 执行粘贴操作 - 使用AppleScript作为备选方案
    private func performPasteOperation() {
        // 首先尝试使用AppleScript执行粘贴
        let script = """
            tell application "System Events"
                keystroke "v" using command down
            end tell
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript paste failed: \(error)")
                // 如果AppleScript失败，回退到CGEvent
                fallbackPasteWithCGEvent()
            }
        } else {
            // 如果无法创建AppleScript，回退到CGEvent
            fallbackPasteWithCGEvent()
        }
    }
    
    // 备选的CGEvent粘贴方法 - 使用更简洁的实现
    private func fallbackPasteWithCGEvent() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        // 创建Command+V组合键事件
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        // 发送按键事件
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
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
        // 清理事件监听器
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        // 清理 CGEventTap
        cleanupEventTap()
        // 清理全局快捷键
        unregisterGlobalHotKey()
        NSApp.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 应用即将退出时清理资源
        cleanupEventTap()
        unregisterGlobalHotKey()
    }
    
    // 清理 CGEventTap
    private func cleanupEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
            print("🧹 CGEventTap 已清理")
        }
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
