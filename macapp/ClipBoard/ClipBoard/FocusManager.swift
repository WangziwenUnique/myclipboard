//
//  FocusManager.swift
//  ClipBoard
//
//  Created by 汪梓文 on 2025/8/20.
//

import Foundation
import AppKit

final class FocusManager {
    static let shared = FocusManager()
    
    private var previousApp: NSRunningApplication?
    
    private init() {}
    
    // MARK: - Public Interface
    
    func capturePreviousFocus() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            print("⚠️ [FocusManager] 无法获取当前前台应用")
            previousApp = nil
            return
        }
        
        // 排除当前应用
        if frontmostApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            print("📱 [FocusManager] 前台应用是自己，寻找其他活跃应用")
            previousApp = findLastActiveNonSelfApp()
        } else {
            previousApp = frontmostApp
        }
        
        if let app = previousApp {
            print("✅ [FocusManager] 已捕获前一个应用焦点: \(app.localizedName ?? "Unknown")")
        } else {
            print("⚠️ [FocusManager] 未找到可恢复的应用")
        }
    }
    
    func restorePreviousFocus() {
        guard let app = previousApp else {
            print("⚠️ [FocusManager] 没有保存的应用焦点信息")
            return
        }
        
        guard app.isTerminated == false else {
            print("⚠️ [FocusManager] 目标应用已终止: \(app.localizedName ?? "Unknown")")
            previousApp = nil
            return
        }
        
        print("🎯 [FocusManager] 恢复应用焦点: \(app.localizedName ?? "Unknown")")
        
        let success = app.activate()
        if success {
            print("✅ [FocusManager] 应用焦点恢复成功")
        } else {
            print("❌ [FocusManager] 应用焦点恢复失败")
        }
        
        // 清理状态，避免重复使用
        previousApp = nil
    }
    
    // MARK: - Private Methods
    
    private func findLastActiveNonSelfApp() -> NSRunningApplication? {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        // 寻找最近活跃的非自身应用
        for app in runningApps {
            if app.bundleIdentifier != Bundle.main.bundleIdentifier &&
               app.activationPolicy == .regular &&
               !app.isTerminated {
                return app
            }
        }
        
        return nil
    }
}