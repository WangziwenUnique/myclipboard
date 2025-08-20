//
//  SettingsWindowController.swift
//  ClipBoard
//
//  Created by Claude on 2025/8/20.
//

import AppKit
import SwiftUI

class SettingsWindowController: NSWindowController {
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        setupWindow()
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "ClipBoard Settings"
        window.center()
        window.isRestorable = false
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        
        // 设置最小尺寸
        window.minSize = NSSize(width: 480, height: 520)
        window.maxSize = NSSize(width: 480, height: 520)
        
        // 设置 SwiftUI 内容
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        window.contentViewController = hostingController
        
        // 确保窗口在前台显示
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
    }
    
    override func showWindow(_ sender: Any?) {
        // 如果窗口已经存在，就直接显示
        if let window = window {
            window.makeKeyAndOrderFront(sender)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            super.showWindow(sender)
        }
    }
}