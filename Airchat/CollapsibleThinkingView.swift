//
//  CollapsibleThinkingView.swift
//  Airchat
//
//  Created by Claude on 2025/6/23.
//

import SwiftUI

struct CollapsibleThinkingView: View {
    let reasoning: String
    @State private var isExpanded = false
    @State private var contentHeight: CGFloat = 0
    
    // 定义更柔和的蓝色
    private let softBlue = Color(red: 0.4, green: 0.6, blue: 0.9)
    
    // Auto-expand if content is short enough
    private var shouldAutoExpand: Bool {
        processedReasoning.count < 150 && processedReasoning.components(separatedBy: .newlines).count <= 3
    }
    
    private var processedReasoning: String {
        // Clean up the reasoning text by removing excessive whitespace
        let cleaned = reasoning
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .replacingOccurrences(of: "  ", with: " ")
        
        return cleaned.isEmpty ? "思考中..." : cleaned
    }
    
    private var previewText: String {
        if processedReasoning == "思考中..." {
            return processedReasoning
        }
        
        if processedReasoning.isEmpty {
            return "正在思考..."
        }
        
        // Take first line or up to 80 characters
        let firstLine = processedReasoning.components(separatedBy: .newlines).first ?? processedReasoning
        let preview = String(firstLine.prefix(80))
        return preview + (firstLine.count > 80 ? "..." : "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with toggle button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("思考过程")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !shouldAutoExpand {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(shouldAutoExpand)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                if isExpanded || shouldAutoExpand {
                    ScrollView(.vertical, showsIndicators: shouldAutoExpand ? false : true) {
                        Text(processedReasoning)
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .fixedSize(horizontal: false, vertical: true)
                            .background(GeometryReader { geometry in
                                Color.clear
                                    .preference(
                                        key: ContentHeightKey.self,
                                        value: geometry.size.height
                                    )
                            })
                    }
                    .frame(height: shouldAutoExpand ? nil : min(max(100, contentHeight), 300))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: contentHeight)
                } else {
                    Text(previewText)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(softBlue.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(softBlue.opacity(0.15), lineWidth: 0.5)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onPreferenceChange(ContentHeightKey.self) { height in
            contentHeight = height
        }
    }
}

// Preference key for measuring content height
struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    VStack {
        CollapsibleThinkingView(reasoning: """
        **Considering the Query**
        
        I've homed in on the core question: "你能做什么？" - What can I do? This follows on from previous interactions, so it's important to remember the context. My prior response identified me as an OpenAI/GPT-4 model.
        
        **Assessing User Intent**
        
        The user is asking about my capabilities in Chinese. They want to understand what I can help them with.
        """)
        .padding()
        .frame(width: 300)
    }
    .background(Color.gray.opacity(0.1))
}