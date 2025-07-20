//
//  CompressibleInputView.swift
//  Airchat
//
//  Created by Claude on 2025/7/20.
//

import SwiftUI

struct CompressibleInputView: View {
    @Binding var text: String
    @State private var isExpanded = false
    @FocusState private var isTextFieldFocused: Bool
    let placeholder: String
    let onSubmit: () -> Void
    
    private var lineCount: Int {
        return text.components(separatedBy: .newlines).count
    }
    
    private var shouldCompress: Bool {
        // 当有多行文本且未手动展开时显示压缩版本
        return lineCount > 2 && !isExpanded
    }
    
    private var compressedSummary: String {
        let lines = lineCount
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = String(cleanText.prefix(30)).replacingOccurrences(of: "\n", with: " ")
        return "[输入 #\(lines)行] \(preview)..."
    }
    
    var body: some View {
        Group {
            if shouldCompress {
                compressedView
            } else {
                expandedView
            }
        }
    }
    
    private var compressedView: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = true
                // 延迟聚焦，确保动画完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
                Text(compressedSummary)
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.blue.opacity(0.7))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .help("点击展开输入框")
    }
    
    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .lineLimit(1...8)
                .focused($isTextFieldFocused)
                .onSubmit {
                    onSubmit()
                }
                .onChange(of: isTextFieldFocused) { _, newValue in
                    if !newValue && lineCount > 2 {
                        // 失去焦点时，如果是多行文本，自动压缩
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded = false
                        }
                    }
                }
            
            // 如果是多行文本且已展开，显示折叠按钮
            if lineCount > 2 && isExpanded && !isTextFieldFocused {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                        Text("折叠")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("点击折叠输入框")
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CompressibleInputView(
            text: .constant("单行文本"),
            placeholder: "输入消息...",
            onSubmit: {}
        )
        
        CompressibleInputView(
            text: .constant("""
            这是一段很长的文本
            包含多行内容
            第三行
            第四行
            第五行
            """),
            placeholder: "输入消息...",
            onSubmit: {}
        )
    }
    .padding()
}