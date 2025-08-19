import SwiftUI

struct SearchBarComponent: View {
    @Binding var text: String
    @Binding var isSidebarVisible: Bool
    @Binding var isWindowPinned: Bool
    @Binding var sortConfig: SortConfiguration
    @State private var showShortcutsPopup = false
    
    var body: some View {
        HStack(spacing: 12) {
            sidebarToggleButton
            searchField
            windowPinButton
            sortMenuButton
            shortcutsButton
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Components
    
    private var sidebarToggleButton: some View {
        Button(action: {
            isSidebarVisible.toggle()
        }) {
            Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.right")
                .foregroundColor(.gray)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(PlainButtonStyle())
        .help("Toggle sidebar")
    }
    
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 16))
                .frame(width: 16, height: 16)
            
            SimpleTextField(text: $text, placeholder: "Type to search...")
            
            if !text.isEmpty {
                Button(action: { 
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(SidebarView.backgroundColor)
        .cornerRadius(12)
    }
    
    private var windowPinButton: some View {
        Button(action: {
            isWindowPinned.toggle()
        }) {
            Image(systemName: isWindowPinned ? "pin.fill" : "pin")
                .foregroundColor(isWindowPinned ? .blue : .gray)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(45))
        }
        .buttonStyle(PlainButtonStyle())
        .help(isWindowPinned ? "Unpin window" : "Pin window")
    }
    
    private var sortMenuButton: some View {
        Menu {
            Button("Last Copy Time") {
                sortConfig.option = .lastCopyTime
            }
            Button("First Copy Time") {
                sortConfig.option = .firstCopyTime
            }
            Button("Number of Copies") {
                sortConfig.option = .numberOfCopies
            }
            Button("Size") {
                sortConfig.option = .size
            }
            Divider()
            Button(sortConfig.isReversed ? "Normal Order" : "Reverse Order") {
                sortConfig.toggleReverse()
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundColor(.gray)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20, height: 20)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .buttonStyle(PlainButtonStyle())
        .menuIndicator(.hidden)
        .accentColor(.gray)
        .tint(.gray)
        .frame(width: 20, height: 20)
        .help("Sort options")
    }
    
    private var shortcutsButton: some View {
        Button(action: {
            showShortcutsPopup.toggle()
        }) {
            Image(systemName: "keyboard")
                .foregroundColor(.gray)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(PlainButtonStyle())
        .help("Show keyboard shortcuts")
        .popover(isPresented: $showShortcutsPopup, arrowEdge: .bottom) {
            KeyboardShortcutsPopup()
        }
    }
}

// 键盘快捷键弹窗
struct KeyboardShortcutsPopup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 4)
            
            Group {
                ShortcutRow(key: "⌘1", description: "History")
                ShortcutRow(key: "⌘2", description: "Favorites")
                ShortcutRow(key: "⌘3", description: "Files")
                ShortcutRow(key: "⌘4", description: "Images")
                ShortcutRow(key: "⌘5", description: "Links")
                ShortcutRow(key: "⌘6", description: "Code")
                ShortcutRow(key: "⌘7", description: "Mail")
                
                Divider().background(Color.gray)
                
                ShortcutRow(key: "⌘C", description: "Copy selected item")
                ShortcutRow(key: "⌘V", description: "Paste from clipboard")
                ShortcutRow(key: "⌘F", description: "Focus search")
                ShortcutRow(key: "⌘A", description: "Select all in search")
                ShortcutRow(key: "⌘W", description: "Close window")
                ShortcutRow(key: "⌘,", description: "Preferences")
            }
        }
        .padding(16)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .cornerRadius(8)
        .frame(width: 240)
    }
}

struct ShortcutRow: View {
    let key: String
    let description: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(red: 0.25, green: 0.25, blue: 0.25))
                .cornerRadius(4)
            
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}