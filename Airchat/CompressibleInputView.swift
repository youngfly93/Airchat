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
    @State private var shouldShowCompressed = false
    @State private var compressedText = ""  // 被压缩的文本
    @State private var continuationText = ""  // 压缩后继续输入的文本
    @FocusState private var isTextFieldFocused: Bool
    let placeholder: String
    let onSubmit: () -> Void
    
    // 定时器用于延迟压缩
    @State private var compressionTimer: Timer?
    
    private var lineCount: Int {
        return text.components(separatedBy: .newlines).count
    }
    
    private var textLength: Int {
        return text.trimmingCharacters(in: .whitespacesAndNewlines).count
    }
    
    private var shouldCompress: Bool {
        // 调试：降低阈值到5字符便于测试
        let result = (textLength > 5 || lineCount > 1) && !isExpanded && shouldShowCompressed
        print("📝 shouldCompress 计算: 文本长度=\(textLength), 行数=\(lineCount), isExpanded=\(isExpanded), shouldShowCompressed=\(shouldShowCompressed), 结果=\(result)")
        return result
    }
    
    private var compressedSummary: String {
        let lines = compressedText.components(separatedBy: .newlines).count
        let length = compressedText.trimmingCharacters(in: .whitespacesAndNewlines).count
        
        if lines > 1 {
            return "[\(lines)行]"
        } else {
            return "[\(length)字符]"
        }
    }
    
    var body: some View {
        if shouldCompress && !compressedText.isEmpty {
            // 压缩状态：显示压缩标签 + 继续输入框
            HStack(spacing: 8) {
                compressedButton
                    .layoutPriority(1) // 给压缩按钮高优先级，但允许收缩
                
                TextField("继续输入...", text: $continuationText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...3)
                    .focused($isTextFieldFocused)
                    .frame(minWidth: 100) // 确保输入框有最小宽度
                    .layoutPriority(2) // 给输入框更高优先级
                    .onSubmit {
                        // 合并文本后提交
                        text = compressedText + (continuationText.isEmpty ? "" : " " + continuationText)
                        onSubmit()
                    }
            }
            .onAppear {
                print("📝 CompressibleInputView 出现 - 压缩状态")
            }
            .onChange(of: continuationText) { _, newValue in
                print("📝 继续输入文本变化: '\(newValue)'")
                // 实时更新合并后的文本
                text = compressedText + (newValue.isEmpty ? "" : " " + newValue)
            }
            .onDisappear {
                compressionTimer?.invalidate()
            }
        } else {
            // 正常状态：显示完整文本框
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...3)
                .focused($isTextFieldFocused)
                .onSubmit {
                    onSubmit()
                }
                .onAppear {
                    print("📝 CompressibleInputView 出现 - 正常状态")
                }
                .onChange(of: text) { oldValue, newValue in
                    print("📝 onChange 触发: 旧值='\(oldValue)', 新值='\(newValue)'")
                    handleTextChange(newValue)
                }
                .onDisappear {
                    compressionTimer?.invalidate()
                }
        }
    }
    
    private func handleTextChange(_ newText: String) {
        // 取消之前的定时器
        compressionTimer?.invalidate()
        
        // 如果已经在压缩状态，不再处理
        if shouldCompress {
            return
        }
        
        // 如果文本变短或为空，立即取消压缩
        let newTextLength = newText.trimmingCharacters(in: .whitespacesAndNewlines).count
        let newLineCount = newText.components(separatedBy: .newlines).count
        
        print("📝 文本变化: 长度=\(newTextLength), 行数=\(newLineCount)")
        
        if newTextLength <= 5 && newLineCount <= 1 {
            print("📝 文本太短，取消压缩")
            shouldShowCompressed = false
            compressedText = ""
            continuationText = ""
            return
        }
        
        // 如果文本满足压缩条件，启动1秒延迟定时器（调试用）
        if newTextLength > 5 || newLineCount > 1 {
            print("📝 文本满足压缩条件，启动1秒定时器")
            compressionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                print("📝 定时器触发，显示压缩状态")
                withAnimation(.easeInOut(duration: 0.3)) {
                    // 保存当前文本到压缩文本
                    compressedText = newText
                    // 清空继续输入文本
                    continuationText = ""
                    // 不要清空主文本，保持显示
                    shouldShowCompressed = true
                }
            }
        }
    }
    
    private var compressedButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                // 展开：将压缩文本和继续输入文本合并回主文本
                text = compressedText + (continuationText.isEmpty ? "" : " " + continuationText)
                // 清空压缩相关状态
                compressedText = ""
                continuationText = ""
                shouldShowCompressed = false
                isExpanded = true
                // 延迟聚焦，确保动画完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                
                Text(compressedSummary)
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(.blue.opacity(0.7))
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .help("点击展开输入框")
        .frame(maxWidth: 150) // 限制按钮最大宽度
        .fixedSize(horizontal: false, vertical: true) // 允许水平压缩，垂直固定
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