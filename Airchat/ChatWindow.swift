//
//  ChatWindow.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import SwiftUI
import MarkdownUI

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
        Image(systemName: "bubble.left.and.bubble.right.fill")
            .font(.title2)
            .foregroundColor(.accentColor)
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
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    isCollapsed = false
                }
            }
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
        .focusable()
        .onKeyPress { press in
            if press.key == .init("v") && press.modifiers.contains(.command) {
                vm.handlePaste()
                return .handled
            }
            return .ignored
        }
        .sheet(isPresented: $vm.showModelSelection) {
            ModelSelectionView(
                modelConfig: vm.modelConfig,
                isPresented: $vm.showModelSelection
            )
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("AI Chat")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    vm.showModelSelection = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 12, weight: .medium))
                        Text(vm.modelConfig.selectedModel.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                
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
                    
                    // 底部哨兵，确保内容始终贴着输入框上沿
                    Color.clear
                        .frame(height: 1)
                        .id("BOTTOM")
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 5) // 确保内容贴近输入框但不被遮挡
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.never)
            .onChange(of: vm.messages.count) {
                // 新增消息时滚动到底部，使用动画
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
            .onReceive(vm.streamingScrollPublisher) { _ in
                // 流式输出期间的实时滚动，无动画确保跟随
                proxy.scrollTo("BOTTOM", anchor: .bottom)
            }
            .onReceive(vm.normalScrollPublisher) { _ in
                // 普通情况下的滚动，带轻微动画
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
        }
    }
    
    private var inputView: some View {
        VStack(spacing: 8) {
            // Show image previews at the top if any images are selected
            if !vm.selectedImages.isEmpty {
                imagePreviewSection
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                // Add button on the left
                addButton
                
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
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var sendButton: some View {
        let isEmpty = vm.composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && vm.selectedImages.isEmpty
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
    
    private var addButton: some View {
        Button(action: {
            vm.showFileImporter = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        .frame(width: 36, height: 36)
        .background(.ultraThinMaterial)
        .clipShape(Circle())
        .fileImporter(
            isPresented: $vm.showFileImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: true
        ) { result in
            vm.handleFileSelection(result)
        }
    }
    
    private var imagePreviewSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.selectedImages) { image in
                    imagePreviewItem(image)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 80)
    }
    
    private func imagePreviewItem(_ image: AttachedImage) -> some View {
        ZStack(alignment: .topTrailing) {
            if image.fileType == .image {
                AsyncImage(url: URL(string: image.url)) { asyncImage in
                    switch asyncImage {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(8)
                    case .failure(_):
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 60)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                // File preview (PDF, etc.)
                VStack(spacing: 4) {
                    Image(systemName: image.fileType.systemIcon)
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                    
                    if let fileName = image.fileName {
                        Text(fileName)
                            .font(.system(size: 8))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 60, height: 60)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            
            Button(action: {
                vm.removeImage(image)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: -5)
        }
        .scaleEffect(vm.animatingImageIDs.contains(image.id) ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: vm.animatingImageIDs.contains(image.id))
    }
    
    @ViewBuilder
    private func bubble(for message: ChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if message.role == .assistant {
                    // Show reasoning first if available (only for supported models)
                    if let reasoning = message.reasoning, 
                       !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       vm.modelConfig.selectedModel.supportsReasoning {
                        CollapsibleThinkingView(reasoning: reasoning)
                            .padding(.bottom, 4)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // Show main content
                    Markdown(message.content.displayText)
                        .markdownTheme(.airchat)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // User message content
                    VStack(alignment: .leading, spacing: 8) {
                        // Show images if present
                        if message.content.hasImages {
                            imageGridView(for: message.content.images)
                        }
                        
                        // Show text if present
                        let text = message.content.displayText
                        if !text.isEmpty {
                            Text(text)
                        }
                    }
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
    
    @ViewBuilder
    private func imageGridView(for images: [AttachedImage]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: min(images.count, 2))
        
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(images) { image in
                AsyncImage(url: URL(string: image.url)) { asyncImage in
                    switch asyncImage {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: 120, maxHeight: 120)
                            .clipped()
                            .cornerRadius(8)
                    case .failure(_):
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    case .empty:
                        ProgressView()
                            .frame(width: 120, height: 120)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }
}