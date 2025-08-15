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
        
        return nil
    }
    
    func getAppIcon(for appName: String) -> NSImage? {
        // 检查缓存
        if let cachedIcon = iconCache[appName] {
            return cachedIcon
        }
        
        // 尝试通过应用名称查找
        if let appURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://")!) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            iconCache[appName] = icon
            return icon
        }
        
        // 尝试在 Applications 目录中查找
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        let appURL = applicationsURL.appendingPathComponent("\(appName).app")
        
        if FileManager.default.fileExists(atPath: appURL.path) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            iconCache[appName] = icon
            return icon
        }
        
        return nil
    }
    
    func getBundleID(for appName: String) -> String? {
        // 尝试在 Applications 目录中查找应用的 bundle ID
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        let appURL = applicationsURL.appendingPathComponent("\(appName).app")
        
        if let bundle = Bundle(url: appURL) {
            return bundle.bundleIdentifier
        }
        
        return nil
    }
}