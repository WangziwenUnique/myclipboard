//
//  KeyboardShortcut.swift
//  ClipBoard
//
//  Created by 汪梓文 on 2025/8/16.
//

import SwiftUI
import AppKit

enum KeyboardShortcutAction: CaseIterable {
    // 全局快捷键
    case toggleApp
    
    // 分类切换
    case selectHistory
    case selectFavorites
    case selectText
    case selectImages
    case selectLinks
    case selectFiles
    case selectMail
    
    // 列表导航
    case navigateUp
    case navigateDown
    case selectItem
    case jumpToTop
    case jumpToBottom
    case selectItem1
    case selectItem2
    case selectItem3
    case selectItem4
    case selectItem5
    case selectItem6
    case selectItem7
    case selectItem8
    case selectItem9
    
    // 搜索功能
    case focusSearch
    case clearSearchOrClose
    case toggleFocus
    
    // 操作功能
    case copyItem
    case deleteItem
    case toggleFavorite
    
    // 窗口控制
    case closeWindow
    case toggleSidebar
    case toggleWindowPin
    
    var keyEquivalent: String {
        switch self {
        case .toggleApp: return "v"
        case .selectHistory: return "1"
        case .selectFavorites: return "2"
        case .selectText: return "3"
        case .selectImages: return "4"
        case .selectLinks: return "5"
        case .selectFiles: return "6"
        case .selectMail: return "7"
        case .navigateUp: return "\u{F700}"  // NSUpArrowFunctionKey
        case .navigateDown: return "\u{F701}"  // NSDownArrowFunctionKey
        case .selectItem: return "\r"  // Return/Enter
        case .jumpToTop: return "\u{F700}"  // NSUpArrowFunctionKey
        case .jumpToBottom: return "\u{F701}"  // NSDownArrowFunctionKey
        case .selectItem1: return "1"
        case .selectItem2: return "2"
        case .selectItem3: return "3"
        case .selectItem4: return "4"
        case .selectItem5: return "5"
        case .selectItem6: return "6"
        case .selectItem7: return "7"
        case .selectItem8: return "8"
        case .selectItem9: return "9"
        case .focusSearch: return "f"
        case .clearSearchOrClose: return "\u{001B}"  // ESC
        case .toggleFocus: return "\t"  // Tab
        case .copyItem: return "c"
        case .deleteItem: return "d"
        case .toggleFavorite: return "b"
        case .closeWindow: return "w"
        case .toggleSidebar: return "t"
        case .toggleWindowPin: return "p"
        }
    }
    
    var modifiers: SwiftUI.EventModifiers {
        switch self {
        case .toggleApp:
            return [.command, .shift]
        case .selectHistory, .selectFavorites, .selectText, .selectImages, .selectLinks, .selectFiles, .selectMail:
            return .command
        case .navigateUp, .navigateDown, .selectItem:
            return []
        case .jumpToTop, .jumpToBottom:
            return .command
        case .selectItem1, .selectItem2, .selectItem3, .selectItem4, .selectItem5, .selectItem6, .selectItem7, .selectItem8, .selectItem9:
            return []
        case .focusSearch:
            return .command
        case .clearSearchOrClose:
            return []
        case .toggleFocus:
            return []
        case .copyItem, .deleteItem, .toggleFavorite:
            return .command
        case .closeWindow, .toggleSidebar, .toggleWindowPin:
            return .command
        }
    }
    
    var displayString: String {
        let modifierString = modifiers.displayString
        let keyString = keyEquivalent.displayString
        return modifierString + keyString
    }
    
    var description: String {
        switch self {
        case .toggleApp: return "显示/隐藏剪贴板窗口"
        case .selectHistory: return "切换到历史记录"
        case .selectFavorites: return "切换到收藏夹"
        case .selectText: return "切换到文本"
        case .selectImages: return "切换到图片"
        case .selectLinks: return "切换到链接"
        case .selectFiles: return "切换到文件"
        case .selectMail: return "切换到邮件"
        case .navigateUp: return "上一项"
        case .navigateDown: return "下一项"
        case .selectItem: return "选择当前项"
        case .jumpToTop: return "跳到顶部"
        case .jumpToBottom: return "跳到底部"
        case .selectItem1: return "选择第1项"
        case .selectItem2: return "选择第2项"
        case .selectItem3: return "选择第3项"
        case .selectItem4: return "选择第4项"
        case .selectItem5: return "选择第5项"
        case .selectItem6: return "选择第6项"
        case .selectItem7: return "选择第7项"
        case .selectItem8: return "选择第8项"
        case .selectItem9: return "选择第9项"
        case .focusSearch: return "聚焦搜索框"
        case .clearSearchOrClose: return "清除搜索或关闭窗口"
        case .toggleFocus: return "切换搜索框和列表焦点"
        case .copyItem: return "复制选中项"
        case .deleteItem: return "删除选中项"
        case .toggleFavorite: return "切换收藏状态"
        case .closeWindow: return "关闭窗口"
        case .toggleSidebar: return "切换侧边栏"
        case .toggleWindowPin: return "切换窗口置顶"
        }
    }
}

extension SwiftUI.EventModifiers {
    var displayString: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}

extension String {
    var displayString: String {
        switch self {
        case "\u{F700}": return "↑"
        case "\u{F701}": return "↓"
        case "\u{F702}": return "←"
        case "\u{F703}": return "→"
        case "\r": return "⏎"
        case "\u{001B}": return "⎋"
        case " ": return "Space"
        default: return self.uppercased()
        }
    }
}

struct KeyboardShortcutInfo {
    let action: KeyboardShortcutAction
    let isEnabled: Bool
    
    init(action: KeyboardShortcutAction, isEnabled: Bool = true) {
        self.action = action
        self.isEnabled = isEnabled
    }
}