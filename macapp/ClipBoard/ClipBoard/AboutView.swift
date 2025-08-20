//
//  AboutView.swift
//  ClipBoard
//
//  Created by Claude on 2025/8/20.
//

import SwiftUI
import AppKit

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // 应用图标
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding(.top, 30)
            
            // 应用名称
            Text("ClipBoard")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 版本信息
            VStack(spacing: 4) {
                Text("Version \(getAppVersion())")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Build \(getBuildNumber())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 描述
            Text("A powerful clipboard manager for macOS")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // 系统信息
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "macOS", value: getSystemVersion())
                InfoRow(label: "Architecture", value: getArchitecture())
                InfoRow(label: "Memory", value: getMemoryInfo())
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 40)
            
            // 版权信息
            VStack(spacing: 8) {
                Text("© 2025 ClipBoard")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    Button("GitHub") {
                        if let url = URL(string: "https://github.com/your-repo/clipbook") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                    
                    Button("Support") {
                        if let url = URL(string: "mailto:support@clipbook.app") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                    
                    Button("Privacy Policy") {
                        if let url = URL(string: "https://github.com/your-repo/clipbook/privacy") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                }
                .font(.caption)
            }
            .padding(.bottom, 20)
            
            // 关闭按钮
            Button("Close") {
                NSApp.keyWindow?.close()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.bottom, 30)
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - 系统信息获取方法
    
    private func getAppVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
    
    private func getBuildNumber() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
    
    private func getSystemVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    private func getArchitecture() -> String {
        #if arch(arm64)
        return "Apple Silicon"
        #elseif arch(x86_64)
        return "Intel"
        #else
        return "Unknown"
        #endif
    }
    
    private func getMemoryInfo() -> String {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(physicalMemory))
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .font(.caption)
    }
}

#Preview {
    AboutView()
}