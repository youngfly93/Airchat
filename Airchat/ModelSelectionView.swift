//
//  ModelSelectionView.swift
//  Airchat
//
//  Created by Claude on 2025/6/21.
//

import SwiftUI

struct ModelSelectionView: View {
    @ObservedObject var modelConfig: ModelConfig
    @Binding var isPresented: Bool
    
    // 定义更柔和的蓝色
    private let softBlue = Color(red: 0.4, green: 0.6, blue: 0.9)
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            modelListView
        }
        .frame(width: 480, height: 560)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .focusable(false) // 禁用焦点环
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("选择AI模型")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("当前: \(modelConfig.selectedModel.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .focusable(false) // 禁用焦点环
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var modelListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(modelConfig.availableModels) { model in
                    ModelCard(
                        model: model,
                        isSelected: model.id == modelConfig.selectedModel.id,
                        onSelect: {
                            modelConfig.selectModel(model)
                            isPresented = false
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

struct ModelCard: View {
    let model: AIModel
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    // 定义更柔和的蓝色
    private let softBlue = Color(red: 0.4, green: 0.6, blue: 0.9)
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                isSelected ? softBlue.opacity(0.1) : 
                (isHovered ? Color.white.opacity(0.05) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? softBlue.opacity(0.3) : 
                        (isHovered ? Color.white.opacity(0.2) : Color.white.opacity(0.1)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if model.supportsReasoning {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                        }
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(softBlue)
                        }
                    }
                    
                    Text(model.provider)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(softBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(softBlue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            Text(model.description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("上下文窗口")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatContextWindow(model.contextWindow))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("定价 (每1M tokens)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("输入: $\(model.pricing.input, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("输出: $\(model.pricing.output, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .contentShape(Rectangle()) // 确保整个区域都可以点击
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                onSelect()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .focusable(false) // 禁用焦点环
    }
    
    private func formatContextWindow(_ tokens: Int) -> String {
        if tokens >= 1000000 {
            return "\(tokens / 1000000)M"
        } else if tokens >= 1000 {
            return "\(tokens / 1000)K"
        } else {
            return "\(tokens)"
        }
    }
}

#Preview {
    ModelSelectionView(
        modelConfig: ModelConfig(),
        isPresented: .constant(true)
    )
}