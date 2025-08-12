//
//  ClipBoardApp.swift
//  ClipBoard
//
//  Created by 汪梓文 on 2025/8/11.
//

import SwiftUI
import AppKit

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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 首先设置激活策略，确保应用不显示在 Dock 中
        NSApp.setActivationPolicy(.accessory)
        
        // 创建状态栏图标
        setupStatusBar()
        
        // 创建主窗口但不显示
        setupMainWindow()
        
        // 设置全局事件监听器，用于检测窗口失去焦点
        setupEventMonitor()
        
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
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 540),
            styleMask: [.borderless],
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
        
        // 禁止窗口大小调整
        window?.minSize = NSSize(width: 820, height: 540)
        window?.maxSize = NSSize(width: 820, height: 540)
        
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
    
    private func setupGlobalHotkeys() {
        // 这里可以添加全局快捷键支持，比如 Cmd+Shift+V 打开剪贴板
        // 由于需要额外的权限和复杂性，这里暂时留空
        // 在实际应用中，可以使用第三方库如 HotKey 或 MASShortcut
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

            // 先激活应用，确保第一次点击即可聚焦输入框
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
    
    @objc private func quitApp() {
        // 清理事件监听器
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        NSApp.terminate(nil)
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
}
