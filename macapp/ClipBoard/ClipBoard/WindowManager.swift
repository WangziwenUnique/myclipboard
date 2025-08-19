import Foundation
import SwiftUI
import AppKit
import Carbon

final class WindowManager: NSObject {
    static let shared = WindowManager()
    
    private var window: NSWindow?
    private var eventMonitor: Any?
    private var eventTap: CFMachPort?
    private var shortcutManager = KeyboardShortcutManager.shared
    private var globalHotKeyRef: EventHotKeyRef?
    
    // 防抖机制相关
    private var lastHotKeyTime: Date = Date.distantPast
    private let hotKeyDebounceInterval: TimeInterval = 0.3
    
    // 事件去重相关
    private var lastKeyEvent: (keyCode: UInt16, timestamp: Date) = (0, Date.distantPast)
    private let keyEventDebounceInterval: TimeInterval = 0.1
    
    // UserDefaults keys
    private let windowWidthKey = "ClipBoard.WindowWidth"
    private let windowHeightKey = "ClipBoard.WindowHeight"
    
    private override init() {}
    
    // MARK: - Public Interface
    
    func setupMainWindow() {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.layer?.cornerRadius = 12.0
        containerView.layer?.masksToBounds = true
        
        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)
        
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        hostingController.view.layer?.cornerRadius = 12.0
        hostingController.view.layer?.masksToBounds = true
        
        hostingController.view.layer?.borderWidth = 0.5
        hostingController.view.layer?.borderColor = NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 0.3).cgColor
        
        containerView.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
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
        
        window?.collectionBehavior = [.transient, .fullScreenAuxiliary, .stationary]
        window?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
        window?.hidesOnDeactivate = false
        
        window?.backgroundColor = NSColor.clear
        window?.isOpaque = false
        window?.hasShadow = true
        
        window?.contentView?.wantsLayer = true
        window?.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        window?.isMovableByWindowBackground = true
        window?.acceptsMouseMovedEvents = true
        
        window?.minSize = NSSize(width: 720, height: 480)
        window?.maxSize = NSSize(width: 1600, height: 1200)
        
        window?.orderOut(nil)
    }
    
    func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let window = self?.window, window.isVisible {
                let globalLocation = NSEvent.mouseLocation
                let windowFrame = window.frame
                
                if !windowFrame.contains(globalLocation) {
                    self?.hideWindow()
                }
            }
        }
    }
    
    func setupGlobalKeyboardEventMonitor() {
        guard AXIsProcessTrusted() else {
            print("❌ 无辅助功能权限，CGEventTap无法正常工作")
            return
        }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let windowManager = Unmanaged<WindowManager>.fromOpaque(refcon).takeUnretainedValue()
            
            return windowManager.handleCGKeyEvent(proxy: proxy, type: type, event: event)
        }
        
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
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
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: false)
        
        print("✅ CGEventTap 已设置（初始禁用状态）")
    }
    
    func setupGlobalHotkeys() {
        registerGlobalHotKey()
    }
    
    func showMainWindow() {
        guard let window = window else { return }
        
        print("🚀 准备显示主窗口")
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            
            let centerX = screenFrame.midX - windowFrame.width / 2
            let centerY = screenFrame.midY - windowFrame.height / 2
            
            let windowOrigin = NSPoint(x: centerX, y: centerY)
            window.setFrameOrigin(windowOrigin)
        } else {
            window.center()
        }

        print("🚀 显示浮层窗口（纯浮层模式）")
        
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
        window.orderFront(nil)
        window.orderFrontRegardless()
        
        enableEventTap()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("📤 发送重置选择索引通知")
            NotificationCenter.default.post(name: .resetSelection, object: nil)
        }
        
        print("✅ 纯浮层窗口显示完成，依赖全局监听器处理快捷键")
    }
    
    func hideWindow() {
        guard let window = window else { return }
        window.orderOut(nil)
        disableEventTap()
    }
    
    func performDirectPaste() {
        hideWindow()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.performPasteOperation()
        }
    }
    
    func toggleWindow() {
        guard let window = window else { return }
        
        if window.isVisible {
            hideWindow()
        } else {
            showMainWindow()
        }
    }
    
    func cleanup() {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        cleanupEventTap()
        unregisterGlobalHotKey()
    }
    
    // MARK: - Private Methods
    
    private func handleCGKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        
        guard let window = window, window.isVisible else {
            return Unmanaged.passUnretained(event)
        }
        
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let modifiers = convertCGModifiersToEventModifiers(flags)
        
        let keyName = getKeyName(for: keyCode)
        let modifierStr = formatModifiers(modifiers)
        print("🎯 [CGEventTap] 检测到按键：keyCode=\(keyCode) (\(keyName)) modifiers=\(modifierStr)")
        
        if isClipboardShortcut(keyCode, modifiers: modifiers) {
            print("   - ✅ 快捷键已处理，消费事件")
            return nil
        } else {
            print("   - ✏️ 文本输入，注入到搜索框")
            let handled = handleTextInput(keyCode, modifiers: modifiers)
            if handled {
                print("   - ✅ 文本输入已处理，消费事件")
                return nil
            }
        }
        
        print("   - ❌ 按键未处理，继续传播")
        return Unmanaged.passUnretained(event)
    }
    
    private func isClipboardShortcut(_ keyCode: UInt16, modifiers: SwiftUI.EventModifiers) -> Bool {
        return shortcutManager.handleKeyCode(keyCode, modifiers: modifiers)
    }
    
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
    
    private func handleTextInput(_ keyCode: UInt16, modifiers: SwiftUI.EventModifiers) -> Bool {
        print("   ✏️ 处理文本输入 keyCode=\(keyCode)")
        
        switch keyCode {
        case 51: // Backspace
            print("   ⌫ 退格键 - 注入到搜索框")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .textInputCommand, object: ["action": "backspace"])
            }
            return true
            
        case 49: // Space
            print("   ␣ 空格键 - 注入到搜索框")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .textInputCommand, object: ["action": "insert", "character": " "])
            }
            return true
            
        default:
            if let character = keyCodeToCharacter(keyCode, modifiers: modifiers) {
                print("   ⌨️ 输入字符: '\(character)' - 注入到搜索框")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .textInputCommand, object: ["action": "insert", "character": character])
                }
                return true
            } else {
                print("   ❌ 无法转换的按键: \(keyCode)")
                return false
            }
        }
    }
    
    private func keyCodeToCharacter(_ keyCode: UInt16, modifiers: SwiftUI.EventModifiers) -> String? {
        let basicKeyMap: [UInt16: String] = [
            12: "q", 13: "w", 14: "e", 15: "r", 17: "t", 16: "y", 32: "u", 34: "i", 31: "o", 35: "p",
            0: "a", 1: "s", 2: "d", 3: "f", 5: "g", 4: "h", 38: "j", 40: "k", 37: "l",
            6: "z", 7: "x", 8: "c", 9: "v", 11: "b", 45: "n", 46: "m",
            29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9"
        ]
        
        let symbolKeyMap: [UInt16: String] = [
            27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/", 50: "`"
        ]
        
        let shiftSymbolKeyMap: [UInt16: String] = [
            29: ")", 18: "!", 19: "@", 20: "#", 21: "$", 23: "%", 22: "^", 26: "&", 28: "*", 25: "(",
            27: "_", 24: "+", 33: "{", 30: "}", 42: "|", 41: ":", 39: "\"", 43: "<", 47: ">", 44: "?", 50: "~"
        ]
        
        if modifiers.contains(.shift) {
            if let shiftChar = shiftSymbolKeyMap[keyCode] {
                return shiftChar
            }
            if let basicChar = basicKeyMap[keyCode] {
                return basicChar.uppercased()
            }
        } else {
            if let basicChar = basicKeyMap[keyCode] {
                return basicChar
            }
            if let symbolChar = symbolKeyMap[keyCode] {
                return symbolChar
            }
        }
        
        switch keyCode {
        case 48: // Tab
            return "\t"
        case 36: // Return/Enter
            return "\n"
        default:
            return nil
        }
    }
    
    private func registerGlobalHotKey() {
        let hotKeyId = EventHotKeyID(signature: OSType(0x53484356), id: 1)
        let modifiers = UInt32(shiftKey | cmdKey)
        let keyCode = UInt32(9) // V key
        
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let windowManager = Unmanaged<WindowManager>.fromOpaque(userData).takeUnretainedValue()
            
            var hotKeyId = EventHotKeyID()
            GetEventParameter(theEvent, OSType(kEventParamDirectObject), OSType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyId)
            
            if hotKeyId.signature == OSType(0x53484356) && hotKeyId.id == 1 {
                Task { @MainActor in
                    windowManager.handleGlobalHotKey()
                }
            }
            
            return noErr
        }, 1, &eventSpec, selfPtr, nil)
        
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyId, GetApplicationEventTarget(), 0, &globalHotKeyRef)
        
        if status != noErr {
            print("Failed to register global hotkey with status: \(status)")
        } else {
            print("Successfully registered global hotkey Shift+Cmd+V")
        }
    }
    
    private func handleGlobalHotKey() {
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastHotKeyTime) < hotKeyDebounceInterval {
            print("🚫 全局热键防抖：忽略重复调用")
            return
        }
        lastHotKeyTime = currentTime
        
        print("⚡ 处理全局快捷键 Shift+Cmd+V")
        
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
    
    private func performPasteOperation() {
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
                fallbackPasteWithCGEvent()
            }
        } else {
            fallbackPasteWithCGEvent()
        }
    }
    
    private func fallbackPasteWithCGEvent() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func enableEventTap() {
        guard let eventTap = eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        print("⚡ CGEventTap 已启用")
    }
    
    private func disableEventTap() {
        guard let eventTap = eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: false)
        print("💤 CGEventTap 已禁用")
    }
    
    private func cleanupEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
            print("🧹 CGEventTap 已清理")
        }
    }
    
    private func getKeyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        case 36: return "Return"
        case 53: return "Escape"
        case 126: return "↑"
        case 125: return "↓"
        case 123: return "←"
        case 124: return "→"
        case 8: return "C"
        case 9: return "V"
        case 51: return "Backspace"
        case 49: return "Space"
        case 48: return "Tab"
        default: return "Unknown(\(keyCode))"
        }
    }
    
    private func formatModifiers(_ modifiers: SwiftUI.EventModifiers) -> String {
        var result = ""
        if modifiers.contains(.command) { result += "⌘" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.control) { result += "⌃" }
        return result.isEmpty ? "none" : result
    }
}

// MARK: - NSWindowDelegate
extension WindowManager: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideWindow()
        return false
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if let window = window, window.isVisible {
            hideWindow()
        }
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // 窗口获得焦点时的处理
    }
    
    func windowWillClose(_ notification: Notification) {
        // 窗口关闭时的处理
    }
    
    func windowDidResize(_ notification: Notification) {
        if let window = window {
            let size = window.frame.size
            UserDefaults.standard.set(size.width, forKey: windowWidthKey)
            UserDefaults.standard.set(size.height, forKey: windowHeightKey)
        }
    }
}