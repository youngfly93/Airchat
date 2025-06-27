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
    @State private var animationProgress: Double = 1.0
    @State private var isInputFocused = false
    
    // 定义更柔和的蓝色
    private let softBlue = Color(red: 0.4, green: 0.6, blue: 0.9)
    
    var body: some View {
        // 简单的即时切换，避免任何SwiftUI动画重影
        Group {
            if isCollapsed {
                collapsedView
            } else {
                expandedView
            }
        }
        .background(Color.clear)
        .onReceive(NotificationCenter.default.publisher(for: .windowStateChanged)) { notification in
            if let userInfo = notification.userInfo,
               let collapsed = userInfo["isCollapsed"] as? Bool {
                // 立即切换，不使用任何SwiftUI动画
                isCollapsed = collapsed
            }
        }
    }
    
    private var collapsedView: some View {
        ZStack {
            // 主要点击区域 - 单击展开
            Rectangle()
                .fill(Color.clear)
                .frame(width: 60, height: 60)
                .contentShape(Rectangle())
                .onTapGesture {
                    WindowManager.shared.toggleWindowState(collapsed: false)
                }
            
            // 主图标 - 不可点击
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title2)
                .foregroundColor(softBlue)
                .allowsHitTesting(false)
            
        }
        .frame(width: 60, height: 60)
        .background(
            AnimationCompatibleVisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        // 简化阴影以提高性能
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
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
            AnimationCompatibleVisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        // 简化阴影以提高性能
        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
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
        .sheet(isPresented: $vm.showAPIKeyInput) {
            APIKeyInputView(isPresented: $vm.showAPIKeyInput)
        }
        .alert("清空聊天记录", isPresented: $vm.showClearConfirmation) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                vm.clearChat()
            }
        } message: {
            Text("确定要清空所有聊天记录吗？此操作无法撤销。")
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 0) {
            // 左侧窗口控制区域
            HStack(spacing: 8) {
                // 重新构建的折叠按钮
                collapseButton
                
                // Logo图标 - 更大尺寸
                if let logoImage = NSImage(named: "MenuIcon") {
                    Image(nsImage: logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.primary)
                } else {
                    // 备用图标
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // 右侧工具栏 - 统一视觉层级
            HStack(spacing: 8) {
                // 模式选择器 - 统一样式
                Button(action: {
                    vm.showModelSelection = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 11, weight: .medium))
                        Text(vm.modelConfig.selectedModel.name)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                
                // 清空按钮 - 改为垃圾桶图标，统一样式
                Button(action: {
                    vm.showClearConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
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
                // 改进的添加按钮 - 与发送按钮保持一致的圆形设计
                enhancedAddButton
                
                // 改进的输入框 - 自适应高度 + 毛玻璃背景 + 焦点边框
                enhancedInputField
                
                // 改进的发送按钮 - 添加快捷键提示
                enhancedSendButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
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
                        .foregroundColor(softBlue)
                    
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
                Group {
                    if message.role == .assistant {
                        // AI消息 - 浅灰色毛玻璃背景
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThickMaterial)
                    } else {
                        // 用户消息 - 蓝色主题背景
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(softBlue.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(softBlue.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }
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
    
    // 全新构建的折叠按钮 - 与其他按钮样式协调
    private var collapseButton: some View {
        Circle()
            .fill(.regularMaterial)
            .frame(width: 24, height: 24)
            .overlay(
                // 减号图标 - 调整颜色和字体以匹配其他按钮
                Text("−")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary) // 使用primary颜色与其他按钮一致
            )
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5) // 与其他按钮边框一致
            )
            .onTapGesture {
                WindowManager.shared.toggleWindowState(collapsed: true)
            }
    }
    
    // MARK: - 增强的底部输入区组件
    
    // 增强的输入框 - 合适高度 + 上下居中 + 毛玻璃背景 + 焦点边框
    private var enhancedInputField: some View {
        ZStack {
            // 占位符文本 - 完全居中
            if vm.composing.isEmpty {
                HStack {
                    Text("输入内容…")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            
            TextEditor(text: $vm.composing)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden) // 隐藏默认背景
                .padding(.horizontal, 8)
                .padding(.vertical, 8) // 增加垂直内边距确保居中
                .onTapGesture {
                    isInputFocused = true
                }
        }
        .frame(height: 42) // 稍微增加高度到42px
        .background(.regularMaterial) // 毛玻璃背景
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous)) // 调整圆角匹配高度
        .overlay(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .strokeBorder(
                    isInputFocused ? softBlue.opacity(0.6) : Color.clear,
                    lineWidth: 1
                )
                .animation(.easeInOut(duration: 0.2), value: isInputFocused)
        )
        .onTapGesture {
            isInputFocused = true
        }
    }
    
    // 增强的发送按钮 - 添加快捷键提示
    private var enhancedSendButton: some View {
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
        .background(isDisabled ? Color.gray.opacity(0.3) : softBlue)
        .clipShape(Circle())
        .disabled(isDisabled)
        .keyboardShortcut(.return, modifiers: [.command])
        .help("⌘↩︎ 发送") // 快捷键提示
    }
    
    // 增强的添加按钮 - 与发送按钮保持一致的圆形设计
    private var enhancedAddButton: some View {
        Button(action: {
            vm.showFileImporter = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .frame(width: 36, height: 36)
        .background(.regularMaterial) // 改为regularMaterial保持一致
        .clipShape(Circle())
        .fileImporter(
            isPresented: $vm.showFileImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: true
        ) { result in
            vm.handleFileSelection(result)
        }
        .help("添加文件或图片")
    }
}