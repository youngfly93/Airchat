//
//  CompressibleMessageView.swift
//  Airchat
//
//  Created by Claude on 2025/7/20.
//

import SwiftUI
import MarkdownUI

struct CompressibleMessageView: View {
    let message: ChatMessage
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if message.content.shouldCompress && !isExpanded {
                // 压缩状态显示
                compressedView
            } else {
                // 完整显示
                fullContentView
            }
        }
    }
    
    private var compressedView: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = true
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
                Text(message.content.compressedSummary)
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
        .help("点击展开完整内容")
    }
    
    private var fullContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 完整文本内容
            if message.content.hasImages {
                // 多模态内容显示
                MultimodalContentView(content: message.content, role: message.role)
            } else {
                // 根据角色选择显示方式
                if message.role == .assistant {
                    Markdown(message.content.displayText)
                        .markdownTheme(.airchat)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(message.content.displayText)
                        .font(.system(size: 14))
                        .textSelection(.enabled)
                }
            }
            
            // 如果原本需要压缩，显示折叠按钮
            if message.content.shouldCompress {
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
                .help("点击折叠内容")
            }
        }
    }
}

// 多模态内容显示组件
struct MultimodalContentView: View {
    let content: MessageContent
    let role: ChatMessage.Role
    
    var body: some View {
        if case .multimodal(let parts) = content {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    switch part {
                    case .text(let text):
                        if !text.isEmpty {
                            if role == .assistant {
                                Markdown(text)
                                    .markdownTheme(.airchat)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text(text)
                                    .font(.system(size: 14))
                                    .textSelection(.enabled)
                            }
                        }
                    case .imageUrl(let image):
                        AsyncImage(url: URL(string: image.url)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 200, maxHeight: 150)
                                    .cornerRadius(8)
                            case .failure(_):
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            case .empty:
                                ProgressView()
                                    .frame(width: 50, height: 50)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    case .audioData(_, _):
                        HStack {
                            Image(systemName: "waveform")
                            Text("音频文件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // 短文本消息
        CompressibleMessageView(
            message: ChatMessage(role: .user, content: "这是一条短消息")
        )
        
        // 长文本消息
        CompressibleMessageView(
            message: ChatMessage(role: .user, content: """
            这是一条很长的消息
            包含多行内容
            第三行
            第四行
            第五行
            """)
        )
    }
    .padding()
}