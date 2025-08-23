//
//  KeyboardShortcutManager.swift
//  ClipBoard
//
//  Created by 汪梓文 on 2025/8/16.
//

import SwiftUI
import Combine

// 全局单例快捷键管理器
class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()
    
    // 简化状态管理，移除不必要的 @Published 属性
    private var registeredShortcuts: [KeyboardShortcutAction: KeyboardShortcutInfo] = [:]
    
    // 全局快捷键处理闭包
    private var actionHandlers: [KeyboardShortcutAction: () -> Void] = [:]
    
    // O(1)查找表 - 性能优化
    private var keyCodeLookup: [String: KeyboardShortcutAction] = [:]
    
    // 简化的状态，不需要发布更新
    private var isSearchFocused: Bool = false
    private var isListFocused: Bool = true
    private var currentListIndex: Int = 0
    private var listItemsCount: Int = 0
    
    private init() {
        setupDefaultShortcuts()
        buildLookupTables()
    }
    
    private func setupDefaultShortcuts() {
        // 注册所有默认快捷键
        for action in KeyboardShortcutAction.allCases {
            registeredShortcuts[action] = KeyboardShortcutInfo(action: action)
        }
    }
    
    // 构建O(1)查找表以优化性能
    private func buildLookupTables() {
        keyCodeLookup.removeAll()
        
        for action in KeyboardShortcutAction.allCases {
            if let lookupKey = action.lookupKey {
                keyCodeLookup[lookupKey] = action
            }
        }
        
        print("🔧 [ShortcutManager] 构建查找表完成，包含 \(keyCodeLookup.count) 个快捷键")
    }
    
    // 注册快捷键处理器
    func registerHandler(for action: KeyboardShortcutAction, handler: @escaping () -> Void) {
        actionHandlers[action] = handler
    }
    
    // 执行快捷键动作
    func handleShortcut(_ action: KeyboardShortcutAction) {
        guard let info = registeredShortcuts[action], info.isEnabled else { return }
        actionHandlers[action]?()
    }
    
    // 启用/禁用快捷键
    func setShortcutEnabled(_ action: KeyboardShortcutAction, enabled: Bool) {
        registeredShortcuts[action] = KeyboardShortcutInfo(action: action, isEnabled: enabled)
    }
    
    // 更新列表相关状态
    func updateListState(focusedOnList: Bool, currentIndex: Int, totalCount: Int) {
        isListFocused = focusedOnList
        currentListIndex = max(0, min(currentIndex, totalCount - 1))
        listItemsCount = totalCount
    }
    
    // 获取下一个列表索引
    func getNextListIndex() -> Int {
        guard listItemsCount > 0 else { return 0 }
        return min(currentListIndex + 1, listItemsCount - 1)
    }
    
    // 获取上一个列表索引
    func getPreviousListIndex() -> Int {
        guard listItemsCount > 0 else { return 0 }
        return max(currentListIndex - 1, 0)
    }
    
    
    // 判断快捷键是否应该在当前状态下生效
    func shouldHandleShortcut(_ action: KeyboardShortcutAction) -> Bool {
        guard let info = registeredShortcuts[action], info.isEnabled else { return false }
        
        switch action {
        case .navigateUp, .navigateDown, .jumpToTop, .jumpToBottom:
            return true // 允许在任何状态下进行列表导航
        case .selectItem:
            return true // 回车键在任何状态下都可以使用
        case .focusSearch:
            return true
        case .closeWindow:
            return true // 可以在任何状态下使用
        case .toggleFocus:
            return true // 可以在任何状态下使用
        default:
            return true
        }
    }
    
    // 处理keyCode事件的主要方法 - O(1)查找优化
    func handleKeyCode(_ keyCode: UInt16, modifiers: SwiftUI.EventModifiers) -> Bool {
        let lookupKey = "\(keyCode)_\(modifiers.rawValue)"
        
        print("🎯 [ShortcutManager] handleKeyCode: keyCode=\(keyCode), modifiers=\(modifiers), lookupKey=\(lookupKey)")
        
        guard let action = keyCodeLookup[lookupKey] else {
            print("   ❓ 未找到匹配的快捷键动作")
            return false
        }
        
        print("   ✅ 找到匹配的快捷键动作: \(action)")
        
        if shouldHandleShortcut(action) {
            print("   ⚡ 执行快捷键：\(action)")
            handleShortcut(action)
            return true
        } else {
            print("   ❌ 快捷键被shouldHandleShortcut阻止")
            return false
        }
    }
    
    // 处理键盘事件的兼容方法（保持向后兼容）
    func handleKeyEvent(keyEquivalent: String, modifiers: SwiftUI.EventModifiers) -> Bool {
        print("🎯 [ShortcutManager] handleKeyEvent: keyEquivalent='\(keyEquivalent)', modifiers=\(modifiers)")
        
        for action in KeyboardShortcutAction.allCases {
            if action.keyEquivalent == keyEquivalent && action.modifiers == modifiers {
                print("   ✅ 找到匹配的快捷键动作: \(action)")
                if shouldHandleShortcut(action) {
                    print("   ⚡ 执行快捷键：\(action)")
                    handleShortcut(action)
                    return true
                } else {
                    print("   ❌ 快捷键被shouldHandleShortcut阻止")
                    return false
                }
            }
        }
        print("   ❓ 未找到匹配的快捷键动作")
        return false
    }
    
    // 获取所有可用快捷键信息（用于显示帮助）
    func getAllShortcuts() -> [KeyboardShortcutInfo] {
        return KeyboardShortcutAction.allCases.compactMap { registeredShortcuts[$0] }
    }
    
    // 按类别获取快捷键
    func getShortcutsByCategory() -> [String: [KeyboardShortcutInfo]] {
        return [
            "全局快捷键": [
                .toggleApp
            ].compactMap { registeredShortcuts[$0] },
            
            "分类切换": [
                .selectHistory, .selectFavorites, .selectText, .selectImages, 
                .selectLinks, .selectFiles, .selectMail
            ].compactMap { registeredShortcuts[$0] },
            
            "列表导航": [
                .navigateUp, .navigateDown, .selectItem, .jumpToTop, .jumpToBottom
            ].compactMap { registeredShortcuts[$0] },
            
            "搜索功能": [
                .focusSearch, .closeWindow
            ].compactMap { registeredShortcuts[$0] },
            
            "操作功能": [
                .copyItem, .deleteItem, .toggleFavorite
            ].compactMap { registeredShortcuts[$0] },
            
            "窗口控制": [
                .toggleSidebar, .toggleWindowPin
            ].compactMap { registeredShortcuts[$0] }
        ]
    }
}
