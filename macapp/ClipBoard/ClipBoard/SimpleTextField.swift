import SwiftUI
import AppKit

// 简化的文本输入框 - 消除复杂的通知系统和防抖逻辑
struct SimpleTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.backgroundColor = .clear
        textField.isBordered = false
        textField.focusRingType = .none
        textField.textColor = .white
        textField.font = NSFont.systemFont(ofSize: 14)
        
        // 单行配置
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        textField.maximumNumberOfLines = 1
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: SimpleTextField
        
        init(_ parent: SimpleTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
    }
}