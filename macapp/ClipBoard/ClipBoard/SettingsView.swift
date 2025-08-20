//
//  SettingsView.swift
//  ClipBoard
//
//  Created by Claude on 2025/8/20.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var maxHistoryItems: Double = 100
    @State private var enableKeyboardShortcuts = true
    @State private var enableNotifications = true
    @State private var autoStartup = false
    @State private var enableClipboardMonitoring = true
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("ClipBoard Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            
            // 设置内容
            VStack(alignment: .leading, spacing: 16) {
                // 剪贴板设置
                GroupBox(label: Text("Clipboard").font(.headline)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Max History Items:")
                            Spacer()
                            Text("\(Int(maxHistoryItems))")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $maxHistoryItems, in: 50...500, step: 10)
                        
                        Toggle("Enable Clipboard Monitoring", isOn: $enableClipboardMonitoring)
                    }
                    .padding()
                }
                
                // 快捷键设置
                GroupBox(label: Text("Shortcuts").font(.headline)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Keyboard Shortcuts", isOn: $enableKeyboardShortcuts)
                        
                        if enableKeyboardShortcuts {
                            VStack(alignment: .leading, spacing: 8) {
                                shortcutRow("Show/Hide Window", "⌘Space")
                                shortcutRow("History", "⌘1")
                                shortcutRow("Favorites", "⌘2")
                                shortcutRow("Text", "⌘3")
                                shortcutRow("Images", "⌘4")
                                shortcutRow("Links", "⌘5")
                                shortcutRow("Files", "⌘6")
                                shortcutRow("Mail", "⌘7")
                            }
                            .padding(.leading, 20)
                            .font(.caption)
                        }
                    }
                    .padding()
                }
                
                // 通知设置
                GroupBox(label: Text("Notifications").font(.headline)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Notifications", isOn: $enableNotifications)
                        Toggle("Auto Start at Login", isOn: $autoStartup)
                    }
                    .padding()
                }
                
                Spacer()
                
                // 底部按钮
                HStack {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button("Close") {
                        NSApp.keyWindow?.close()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(.horizontal)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 480, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadSettings()
        }
        .onChange(of: maxHistoryItems) { _, _ in saveSettings() }
        .onChange(of: enableKeyboardShortcuts) { _, _ in saveSettings() }
        .onChange(of: enableNotifications) { _, _ in saveSettings() }
        .onChange(of: autoStartup) { _, _ in saveSettings() }
        .onChange(of: enableClipboardMonitoring) { _, _ in saveSettings() }
    }
    
    private func shortcutRow(_ description: String, _ shortcut: String) -> some View {
        HStack {
            Text(description)
                .foregroundColor(.secondary)
            Spacer()
            Text(shortcut)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
        }
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        maxHistoryItems = defaults.double(forKey: "maxHistoryItems") == 0 ? 100 : defaults.double(forKey: "maxHistoryItems")
        enableKeyboardShortcuts = defaults.object(forKey: "enableKeyboardShortcuts") == nil ? true : defaults.bool(forKey: "enableKeyboardShortcuts")
        enableNotifications = defaults.object(forKey: "enableNotifications") == nil ? true : defaults.bool(forKey: "enableNotifications")
        autoStartup = defaults.bool(forKey: "autoStartup")
        enableClipboardMonitoring = defaults.object(forKey: "enableClipboardMonitoring") == nil ? true : defaults.bool(forKey: "enableClipboardMonitoring")
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(maxHistoryItems, forKey: "maxHistoryItems")
        defaults.set(enableKeyboardShortcuts, forKey: "enableKeyboardShortcuts")
        defaults.set(enableNotifications, forKey: "enableNotifications")
        defaults.set(autoStartup, forKey: "autoStartup")
        defaults.set(enableClipboardMonitoring, forKey: "enableClipboardMonitoring")
    }
    
    private func resetToDefaults() {
        maxHistoryItems = 100
        enableKeyboardShortcuts = true
        enableNotifications = true
        autoStartup = false
        enableClipboardMonitoring = true
        saveSettings()
    }
}

#Preview {
    SettingsView()
}