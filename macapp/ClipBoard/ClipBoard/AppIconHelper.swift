import Foundation
import AppKit

class AppIconHelper {
    static let shared = AppIconHelper()
    private var iconCache: [String: NSImage] = [:]
    
    private init() {}
    
    func getAppIcon(for bundleID: String?) -> NSImage? {
        guard let bundleID = bundleID else { return nil }
        
        // 检查缓存
        if let cachedIcon = iconCache[bundleID] {
            return cachedIcon
        }
        
        // 尝试从 bundle ID 获取应用图标
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: appURL) {
            let icon = NSWorkspace.shared.icon(forFile: bundle.bundlePath)
            iconCache[bundleID] = icon
            return icon
        }
        
        // 如果NSWorkspace无法找到，尝试使用NSRunningApplication
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.bundleIdentifier == bundleID }),
           let bundleURL = app.bundleURL {
            let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
            iconCache[bundleID] = icon
            return icon
        }
        
        return nil
    }
    
    func getAppIcon(for appName: String) -> NSImage? {
        // 检查缓存
        if let cachedIcon = iconCache[appName] {
            return cachedIcon
        }
        
        // 查找路径列表
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Library/CoreServices"
        ]
        
        // 在多个路径中查找应用
        for basePath in searchPaths {
            let applicationsURL = URL(fileURLWithPath: basePath)
            let appURL = applicationsURL.appendingPathComponent("\(appName).app")
            
            if FileManager.default.fileExists(atPath: appURL.path) {
                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                iconCache[appName] = icon
                return icon
            }
        }
        
        // 特殊处理一些常见的系统应用
        let systemAppMappings: [String: String] = [
            "Finder": "/System/Library/CoreServices/Finder.app",
            "System UI Server": "/System/Library/CoreServices/SystemUIServer.app",
            "loginwindow": "/System/Library/CoreServices/loginwindow.app",
            "Dock": "/System/Library/CoreServices/Dock.app",
            "Terminal": "/System/Applications/Utilities/Terminal.app"
        ]
        
        if let systemAppPath = systemAppMappings[appName],
           FileManager.default.fileExists(atPath: systemAppPath) {
            let icon = NSWorkspace.shared.icon(forFile: systemAppPath)
            iconCache[appName] = icon
            return icon
        }
        
        // 最后的备选方案：使用NSWorkspace的通用图标查找
        // 对于一些特殊应用（如Helper应用），可能需要更智能的查找
        if let icon = findIconByWorkspaceSearch(appName: appName) {
            iconCache[appName] = icon
            return icon
        }
        
        return nil
    }
    
    // 辅助方法：通过NSWorkspace进行更广泛的应用搜索
    private func findIconByWorkspaceSearch(appName: String) -> NSImage? {
        // 处理Helper应用的特殊情况
        if appName.contains("Helper") {
            // 尝试找到父应用
            let parentAppName = appName.replacingOccurrences(of: " Helper", with: "")
                                     .replacingOccurrences(of: "Helper", with: "")
                                     .trimmingCharacters(in: .whitespaces)
            
            // 搜索可能的父应用变体
            let possibleParentNames = [
                parentAppName,
                "Lark", // Lark Helper -> Lark
                "Feishu" // Feishu Helper -> Feishu
            ]
            
            for parentName in possibleParentNames {
                let searchPaths = [
                    "/Applications/\(parentName).app",
                    "/Applications/\(parentName)/\(parentName).app"
                ]
                
                for appPath in searchPaths {
                    if FileManager.default.fileExists(atPath: appPath) {
                        return NSWorkspace.shared.icon(forFile: appPath)
                    }
                }
            }
        }
        
        // 尝试通用的应用名称匹配
        let applicationsPath = "/Applications"
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: applicationsPath)
            for item in contents {
                if item.hasSuffix(".app") {
                    let appNameFromPath = (item as NSString).deletingPathExtension
                    if appNameFromPath.localizedCaseInsensitiveContains(appName) || 
                       appName.localizedCaseInsensitiveContains(appNameFromPath) {
                        let fullPath = "\(applicationsPath)/\(item)"
                        return NSWorkspace.shared.icon(forFile: fullPath)
                    }
                }
            }
        } catch {
            print("无法读取Applications目录: \(error)")
        }
        
        return nil
    }
    
    func getBundleID(for appName: String) -> String? {
        // 查找路径列表
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Library/CoreServices"
        ]
        
        // 在多个路径中查找应用的 bundle ID
        for basePath in searchPaths {
            let applicationsURL = URL(fileURLWithPath: basePath)
            let appURL = applicationsURL.appendingPathComponent("\(appName).app")
            
            if let bundle = Bundle(url: appURL) {
                return bundle.bundleIdentifier
            }
        }
        
        // 特殊处理一些常见的系统应用
        let systemAppMappings: [String: String] = [
            "Finder": "/System/Library/CoreServices/Finder.app",
            "System UI Server": "/System/Library/CoreServices/SystemUIServer.app",
            "loginwindow": "/System/Library/CoreServices/loginwindow.app",
            "Dock": "/System/Library/CoreServices/Dock.app",
            "Terminal": "/System/Applications/Utilities/Terminal.app"
        ]
        
        if let systemAppPath = systemAppMappings[appName],
           let bundle = Bundle(path: systemAppPath) {
            return bundle.bundleIdentifier
        }
        
        return nil
    }
}