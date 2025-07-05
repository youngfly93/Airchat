//
//  ChineseInputTextField.swift
//  Airchat
//
//  Created by Claude on 2025/6/21.
//

import SwiftUI
import AppKit

struct ChineseInputTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = CGSize(width: scrollView.frame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 0, height: 2)
        
        // Store in coordinator for placeholder handling
        context.coordinator.textView = textView
        context.coordinator.placeholderString = placeholder
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        
        // Update placeholder visibility
        context.coordinator.updatePlaceholder()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: ChineseInputTextField
        weak var textView: NSTextView?
        var placeholderString: String = ""
        
        init(_ parent: ChineseInputTextField) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            updatePlaceholder()
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSTextView.insertNewline(_:)) {
                // Check if we're in the middle of Chinese input
                if textView.hasMarkedText() {
                    // Let the input method handle it
                    return false
                } else if !NSEvent.modifierFlags.contains(.shift) {
                    // Handle Enter key when not composing and not holding Shift
                    parent.onSubmit()
                    return true
                }
            }
            return false
        }
        
        func updatePlaceholder() {
            textView?.needsDisplay = true
        }
    }
}

// View modifier to use the Chinese-friendly text field
struct ChineseInputTextFieldModifier: ViewModifier {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    
    func body(content: Content) -> some View {
        ChineseInputTextField(
            text: $text,
            placeholder: placeholder,
            onSubmit: onSubmit
        )
        .frame(minHeight: 20, maxHeight: 120) // 🔧 增加最大高度，允许显示更多文本
    }
}

extension View {
    func chineseInputTextField(text: Binding<String>, placeholder: String = "输入内容…", onSubmit: @escaping () -> Void) -> some View {
        self.hidden()
            .overlay(
                ChineseInputTextField(
                    text: text,
                    placeholder: placeholder,
                    onSubmit: onSubmit
                )
            )
    }
}