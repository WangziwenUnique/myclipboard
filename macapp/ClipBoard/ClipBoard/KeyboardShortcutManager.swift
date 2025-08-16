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
    @Published var registeredShortcuts: [KeyboardShortcutAction: KeyboardShortcutInfo] = [:]
    
    // 全局快捷键处理闭包
    var actionHandlers: [KeyboardShortcutAction: () -> Void] = [:]
    
    // 当前焦点状态
    @Published var isSearchFocused: Bool = false
    @Published var isListFocused: Bool = true
    @Published var currentListIndex: Int = 0
    @Published var listItemsCount: Int = 0
    
    private init() {
        setupDefaultShortcuts()
    }
    
    private func setupDefaultShortcuts() {
        // 注册所有默认快捷键
        for action in KeyboardShortcutAction.allCases {
            registeredShortcuts[action] = KeyboardShortcutInfo(action: action)
        }
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
    
    // 根据数字键获取对应的列表索引
    func getListIndexForNumber(_ number: Int) -> Int? {
        guard number >= 1 && number <= 9 && number <= listItemsCount else { return nil }
        return number - 1
    }
    
    // 判断快捷键是否应该在当前状态下生效
    func shouldHandleShortcut(_ action: KeyboardShortcutAction) -> Bool {
        guard let info = registeredShortcuts[action], info.isEnabled else { return false }
        
        switch action {
        case .navigateUp, .navigateDown, .selectItem, .jumpToTop, .jumpToBottom, 
             .selectItem1, .selectItem2, .selectItem3, .selectItem4, .selectItem5,
             .selectItem6, .selectItem7, .selectItem8, .selectItem9:
            return isListFocused && !isSearchFocused
        case .focusSearch:
            return true
        case .clearSearchOrClose:
            return true // 可以在任何状态下使用
        default:
            return true
        }
    }
    
    // 处理键盘事件的主要方法
    func handleKeyEvent(keyEquivalent: String, modifiers: EventModifiers) -> Bool {
        for action in KeyboardShortcutAction.allCases {
            if action.keyEquivalent == keyEquivalent && action.modifiers == modifiers {
                if shouldHandleShortcut(action) {
                    handleShortcut(action)
                    return true
                }
            }
        }
        return false
    }
    
    // 获取所有可用快捷键信息（用于显示帮助）
    func getAllShortcuts() -> [KeyboardShortcutInfo] {
        return KeyboardShortcutAction.allCases.compactMap { registeredShortcuts[$0] }
    }
    
    // 按类别获取快捷键
    func getShortcutsByCategory() -> [String: [KeyboardShortcutInfo]] {
        return [
            "分类切换": [
                .selectHistory, .selectFavorites, .selectText, .selectImages, 
                .selectLinks, .selectFiles, .selectMail
            ].compactMap { registeredShortcuts[$0] },
            
            "列表导航": [
                .navigateUp, .navigateDown, .selectItem, .jumpToTop, .jumpToBottom,
                .selectItem1, .selectItem2, .selectItem3, .selectItem4, .selectItem5,
                .selectItem6, .selectItem7, .selectItem8, .selectItem9
            ].compactMap { registeredShortcuts[$0] },
            
            "搜索功能": [
                .focusSearch, .clearSearchOrClose
            ].compactMap { registeredShortcuts[$0] },
            
            "操作功能": [
                .copyItem, .deleteItem, .toggleFavorite
            ].compactMap { registeredShortcuts[$0] },
            
            "窗口控制": [
                .closeWindow, .toggleSidebar, .toggleWindowPin
            ].compactMap { registeredShortcuts[$0] }
        ]
    }
}