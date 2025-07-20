//
//  MultimodalContentView.swift
//  Airchat
//
//  Created by Claude on 2025/7/20.
//

import SwiftUI
import MarkdownUI

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