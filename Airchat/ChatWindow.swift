//
//  ChatWindow.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import SwiftUI

struct ChatWindow: View {
    @StateObject private var vm = ChatVM()
    @State private var isCollapsed = false
    
    var body: some View {
        if isCollapsed {
            collapsedView
        } else {
            expandedView
        }
    }
    
    private var collapsedView: some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isCollapsed = false
            }
        }) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        .frame(width: 60, height: 60)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .compositingGroup()
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }
    
    private var expandedView: some View {
        VStack(spacing: 0) {
            headerView
            dividerView
            messagesView
            Divider()
            inputView
        }
        .frame(width: 360, height: 520)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .compositingGroup()
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }
    
    private var headerView: some View {
        HStack {
            Text("AI Chat")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        isCollapsed = true
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .background(.thinMaterial)
                .clipShape(Circle())
                
                Button(action: {
                    vm.clearChat()
                }) {
                    Text("Clear")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private var dividerView: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(vm.messages.filter { $0.role != .system }) { message in
                        bubble(for: message)
                            .id(message.id)
                    }
                    
                    if vm.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("AI is thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .onChange(of: vm.messages.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(vm.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: vm.lastMessageUpdateTime) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(vm.messages.last?.id, anchor: .bottom)
                }
            }
        }
    }
    
    private var inputView: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("输入内容…", text: $vm.composing, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onSubmit {
                    if !vm.isLoading {
                        vm.send()
                    }
                }
            
            sendButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var sendButton: some View {
        let isEmpty = vm.composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isDisabled = isEmpty || vm.isLoading
        
        return Button(action: {
            vm.send()
        }) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isDisabled ? .secondary : .white)
        }
        .buttonStyle(.plain)
        .frame(width: 36, height: 36)
        .background(isDisabled ? Color.gray.opacity(0.3) : Color.accentColor)
        .clipShape(Circle())
        .disabled(isDisabled)
        .keyboardShortcut(.return, modifiers: [.command])
    }
    
    @ViewBuilder
    private func bubble(for message: ChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if message.role == .assistant {
                    // Show reasoning first if available
                    if let reasoning = message.reasoning, !reasoning.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("思考过程")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            Text(reasoning)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.accentColor.opacity(0.15), lineWidth: 0.5)
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.bottom, 4)
                    }
                    
                    // Show main content
                    MarkdownText(message.content, isUserMessage: false)
                } else {
                    Text(message.content)
                }
            }
            .padding(12)
            .background(
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            )
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
            
            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }
}