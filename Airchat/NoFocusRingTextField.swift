//
//  NoFocusRingTextField.swift
//  Airchat
//
//  Created by Claude on 2025/6/25.
//

import SwiftUI
import AppKit

// 自定义NSTextField子类，禁用焦点环
class NoFocusRingNSTextField: NSTextField {
    override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}

// SwiftUI包装器
struct NoFocusRingTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NoFocusRingNSTextField {
        let textField = NoFocusRingNSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 14)
        textField.lineBreakMode = .byWordWrapping
        textField.usesSingleLineMode = false
        textField.cell?.wraps = true
        textField.cell?.isScrollable = false
        if let textFieldCell = textField.cell as? NSTextFieldCell {
            textFieldCell.drawsBackground = false
        }
        return textField
    }
    
    func updateNSView(_ nsView: NoFocusRingNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: NoFocusRingTextField
        
        init(_ parent: NoFocusRingTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSTextView.insertNewline(_:)) {
                if !NSEvent.modifierFlags.contains(.shift) {
                    parent.onSubmit()
                    return true
                }
            }
            return false
        }
    }
}