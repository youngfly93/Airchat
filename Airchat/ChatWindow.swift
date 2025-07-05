//
//  ChatWindow.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import SwiftUI
import MarkdownUI
import UniformTypeIdentifiers


struct ChatWindow: View {
    @StateObject private var vm = ChatVM()
    @State private var isCollapsed = false
    @State private var animationProgress: Double = 1.0
    @FocusState private var isInputFocused: Bool
    @FocusState private var isCollapsedInputFocused: Bool
    
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
                
                // 设置焦点
                if collapsed {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isCollapsedInputFocused = true
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInputFocused = true
                    }
                }
            }
        }
    }
    
    private var collapsedView: some View {
        VStack(spacing: 8) {
            // 如果有选中的图片，显示预览
            if !vm.selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.selectedImages) { image in
                            collapsedImagePreview(image)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 60)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 主输入框
            HStack(spacing: 0) {
            // 左侧功能按钮组
            HStack(spacing: 12) {
                // 添加按钮
                Button(action: {
                    vm.showFileImporter = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary.opacity(0.7))
                }
                .buttonStyle(.plain)
                
                // 网络图标
                Button(action: {
                    if vm.supportsWebSearch {
                        vm.toggleWebSearch()
                    }
                }) {
                    Image(systemName: vm.isWebSearchEnabled ? "globe.badge.chevron.backward" : "globe")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(
                            vm.supportsWebSearch 
                                ? (vm.isWebSearchEnabled ? softBlue : .primary.opacity(0.7))
                                : .secondary
                        )
                        .opacity(vm.supportsWebSearch ? 1.0 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(!vm.supportsWebSearch)
                
                // 刷新图标
                Button(action: {
                    // 展开窗口
                    WindowManager.shared.toggleWindowState(collapsed: false)
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("展开窗口")
                
                // 模型显示
                Text(vm.modelConfig.selectedModel.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 16)
            
            Spacer()
            
            // 中间输入框 - 支持多行文本
            TextField("询问任何问题…", text: $vm.composing, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .lineLimit(1...3) // 🔧 添加行数限制，允许多行显示
                .focusable()
                .focused($isCollapsedInputFocused)
                .focusEffectDisabled()
                .onSubmit {
                    let hasContent = !vm.composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !vm.selectedImages.isEmpty
                    if hasContent {
                        // 展开窗口并发送消息
                        WindowManager.shared.toggleWindowState(collapsed: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            vm.send()
                        }
                    }
                }
            
            Spacer()
            
            // 右侧按钮组
            HStack(spacing: 12) {
                // 麦克风按钮 - 语音转文本
                Button(action: {
                    vm.toggleVoiceRecording()
                }) {
                    Image(systemName: vm.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(vm.isRecording ? .red : .secondary)
                        .scaleEffect(vm.isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: vm.isRecording)
                }
                .buttonStyle(.plain)
                .onLongPressGesture {
                    // 长按切换语音识别方法
                    vm.switchSpeechRecognitionMethod()
                }
                .help("点击录音，长按切换识别方式（当前：\(vm.speechRecognitionMethod.displayName)）")
                
                // 发送按钮
                Button(action: {
                    let hasContent = !vm.composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !vm.selectedImages.isEmpty
                    if hasContent {
                        WindowManager.shared.toggleWindowState(collapsed: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            vm.send()
                        }
                    }
                }) {
                    let canSend = !vm.composing.isEmpty || !vm.selectedImages.isEmpty
                    Image(systemName: canSend ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(canSend ? softBlue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(vm.composing.isEmpty && vm.selectedImages.isEmpty)
            }
            .padding(.trailing, 16)
            }
            .frame(width: 480) // 🔧 设置固定宽度
            .frame(minHeight: 64) // 🔧 设置最小高度，允许根据内容动态调整
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(
                        isCollapsedInputFocused ? softBlue.opacity(0.3) : Color.white.opacity(0.1),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress { press in
            if press.key == .init("v") && press.modifiers.contains(.command) {
                vm.handlePaste()
                return .handled
            }
            return .ignored
        }
        .fileImporter(
            isPresented: $vm.showFileImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: true
        ) { result in
            vm.handleFileSelection(result)
        }
        .onTapGesture {
            // 点击输入框时聚焦
            isCollapsedInputFocused = true
        }
        .onAppear {
            // 窗口显示时自动聚焦
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isCollapsedInputFocused = true
            }
        }
        .onDrop(of: [.fileURL, .image, .png, .jpeg, .tiff], isTargeted: nil) { providers in
            for provider in providers {
                // 优先尝试作为文件URL处理
                if provider.canLoadObject(ofClass: URL.self) {
                    _ = provider.loadObject(ofClass: URL.self) { url, error in
                        guard let url = url else { return }
                        
                        // 检查是否为图片文件
                        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
                        if imageExtensions.contains(url.pathExtension.lowercased()) {
                            DispatchQueue.main.async {
                                self.vm.handleDroppedImageFile(at: url)
                            }
                        }
                    }
                }
                // 尝试作为图片数据处理
                else if provider.hasItemConformingToTypeIdentifier("public.image") {
                    _ = provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                        guard let data = data,
                              let image = NSImage(data: data) else { return }
                        DispatchQueue.main.async {
                            self.vm.handleDroppedImage(image)
                        }
                    }
                }
            }
            return true
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
        .frame(width: 360)
        .frame(minHeight: 520, maxHeight: 550) // 🔧 降低最大高度，保持更紧凑的界面
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
        .focusEffectDisabled()
        .onKeyPress { press in
            if press.key == .init("v") && press.modifiers.contains(.command) {
                vm.handlePaste()
                return .handled
            }
            return .ignored
        }
        .onTapGesture {
            // 点击其他区域时，如果输入框为空则重置焦点状态
            if vm.composing.isEmpty {
                isInputFocused = false
            }
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
                
                // Logo图标 - 与菜单栏图标尺寸保持一致
                if let logoImage = NSImage(named: "MenuIcon") {
                    Image(nsImage: logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)  // 从 28x28 增大到 32x32
                        .foregroundStyle(.primary)
                } else {
                    // 备用图标
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 22, weight: .medium))  // 从 20 增大到 22
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
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                }
                .buttonStyle(.plain)
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
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    // 确保至少有一个元素，避免完全空白
                    if vm.messages.filter({ $0.role != .system && $0.role != .tool }).isEmpty && !vm.isLoading {
                        Text("开始对话吧...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                    
                    ForEach(vm.messages.filter { $0.role != .system && $0.role != .tool }) { message in
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
                .frame(minHeight: 100) // 设置最小高度，防止内容过少时的布局问题
            }
            .scrollBounceBehavior(.basedOnSize)
            .clipped() // 防止内容溢出滚动视图边界
            .background(Color.clear) // 确保背景透明
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.count) {
                // 新增消息时滚动到底部，使用优化的动画
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
            .onReceive(vm.streamingScrollPublisher) { _ in
                // 流式输出期间的实时滚动，无动画确保跟随
                proxy.scrollTo("BOTTOM", anchor: .bottom)
            }
            .onReceive(vm.normalScrollPublisher) { _ in
                // 普通情况下的滚动，使用更快速的动画
                withAnimation(.interpolatingSpring(stiffness: 400, damping: 25)) {
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
            
            // 新的输入框设计 - 参考左侧布局
            newInputBarDesign
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // 新的输入框设计 - 模仿左侧参考设计
    private var newInputBarDesign: some View {
        HStack(spacing: 0) {
            // 左侧功能图标组
            HStack(spacing: 12) {
                // 添加按钮
                Button(action: {
                    vm.showFileImporter = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                // 网络图标 - 联网搜索开关
                Button(action: {
                    if vm.supportsWebSearch {
                        vm.toggleWebSearch()
                    }
                }) {
                    Image(systemName: vm.isWebSearchEnabled ? "globe.badge.chevron.backward" : "globe")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(
                            vm.supportsWebSearch 
                                ? (vm.isWebSearchEnabled ? softBlue : .primary)
                                : .secondary
                        )
                        .opacity(vm.supportsWebSearch ? 1.0 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(!vm.supportsWebSearch)
                .help(vm.supportsWebSearch 
                      ? (vm.isWebSearchEnabled ? "关闭联网搜索" : "开启联网搜索")
                      : "当前模型不支持联网搜索")
                
                // 附件图标 (使用现有功能)
                Button(action: {
                    vm.showFileImporter = true
                }) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                // 刷新图标 (暂时不实现功能)
                Button(action: {}) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                // 显示当前模型
                Text(vm.modelConfig.selectedModel.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        vm.showModelSelection = true
                    }
            }
            .padding(.leading, 16)
            
            Spacer()
            
            // 中间输入框
            enhancedCenterInputField
            
            Spacer()
            
            // 右侧按钮组
            HStack(spacing: 12) {
                // 麦克风按钮 - 语音转文本
                Button(action: {
                    vm.toggleVoiceRecording()
                }) {
                    Image(systemName: vm.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(vm.isRecording ? .red : .secondary)
                        .scaleEffect(vm.isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: vm.isRecording)
                }
                .buttonStyle(.plain)
                .onLongPressGesture {
                    // 长按切换语音识别方法
                    vm.switchSpeechRecognitionMethod()
                }
                .help("点击录音，长按切换识别方式（当前：\(vm.speechRecognitionMethod.displayName)）")
                
                // 发送按钮
                enhancedCompactSendButton
            }
            .padding(.trailing, 16)
        }
        .frame(minHeight: 50, maxHeight: 80) // 🔧 降低最大高度，保持更紧凑的界面
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(
                    isInputFocused ? softBlue.opacity(0.6) : Color.clear,
                    lineWidth: 1
                )
                .animation(.easeInOut(duration: 0.2), value: isInputFocused)
        )
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
                        // 只有当这是最后一条助手消息且正在加载时，才是流式模式
                        let isLastAssistantMessage = vm.messages.last(where: { $0.role == .assistant })?.id == message.id
                        let isStreamingThisMessage = isLastAssistantMessage && vm.isLoading
                        
                        CollapsibleThinkingView(
                            reasoning: reasoning,
                            isCompleted: !isStreamingThisMessage
                        )
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
            placeholderText
            inputTextEditor
        }
        .frame(minHeight: 42, maxHeight: 100) // 🔧 设置合理的高度范围
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(inputBorder)
        .onTapGesture {
            isInputFocused = true
        }
    }
    
    // 中间输入框 - 用于新设计 (修复占位符重叠问题和文本覆盖问题)
    private var enhancedCenterInputField: some View {
        ZStack(alignment: .leading) {
            // 🔧 修复占位符显示逻辑，确保不与用户输入重叠
            // 只有在完全无内容且未聚焦时才显示占位符
            if vm.composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isInputFocused {
                Text("询问任何问题")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .allowsHitTesting(false) // 防止占位符阻挡点击
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            }

            TextField("", text: $vm.composing, axis: .vertical)
                .font(.system(size: 14))
                .textFieldStyle(.plain)
                .lineLimit(1...8) // 🔧 增加最大行数限制，允许更多文本显示
                .focused($isInputFocused) // 🔧 使用@FocusState绑定
                .opacity(vm.composing.isEmpty && !isInputFocused ? 0.01 : 1.0) // 🔧 防止透明TextField阻挡占位符
                .onChange(of: vm.composing) { oldValue, newValue in
                    // 🔧 改进焦点管理：有内容时保持聚焦
                    if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isInputFocused {
                        isInputFocused = true
                    }
                }
                .onSubmit {
                    if !vm.composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !vm.selectedImages.isEmpty {
                        vm.send()
                    }
                }
        }
        .frame(minWidth: 120)
        .contentShape(Rectangle()) // 🔧 确保整个区域可点击
        .onTapGesture {
            // 🔧 点击时聚焦输入框
            isInputFocused = true
        }
    }
    
    // 紧凑发送按钮 - 用于新设计
    private var enhancedCompactSendButton: some View {
        let isEmpty = vm.composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && vm.selectedImages.isEmpty
        let isDisabled = isEmpty || vm.isLoading
        
        return Button(action: {
            vm.send()
        }) {
            Image(systemName: isDisabled ? "arrow.up.circle" : "arrow.up.circle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isDisabled ? .secondary : softBlue)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .keyboardShortcut(.return, modifiers: [.command])
        .help("↩︎ 发送 | ⇧↩︎ 换行")
    }
    
    private var placeholderText: some View {
        Group {
            if vm.composing.isEmpty && !isInputFocused {
                HStack {
                    Text("输入内容…")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
    }
    
    private var inputTextEditor: some View {
        TextField("", text: $vm.composing, axis: .vertical)
            .font(.system(size: 14))
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .lineLimit(1...8) // 🔧 增加最大行数限制，允许更多文本显示
            .onTapGesture {
                isInputFocused = true
            }
            .onChange(of: vm.composing) { oldValue, newValue in
                if !newValue.isEmpty {
                    isInputFocused = true
                }
            }
            .onSubmit {
                // Enter 键提交时发送消息
                if !vm.composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !vm.selectedImages.isEmpty {
                    vm.send()
                }
            }
    }
    
    private var inputBorder: some View {
        RoundedRectangle(cornerRadius: 21, style: .continuous)
            .strokeBorder(
                isInputFocused ? softBlue.opacity(0.6) : Color.clear,
                lineWidth: 1
            )
            .animation(.easeInOut(duration: 0.2), value: isInputFocused)
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
        .help("↩︎ 发送 | ⇧↩︎ 换行") // 快捷键提示
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
    
    // 折叠状态下的图片预览
    @ViewBuilder
    private func collapsedImagePreview(_ image: AttachedImage) -> some View {
        ZStack(alignment: .topTrailing) {
            if image.fileType == .image {
                AsyncImage(url: URL(string: image.url)) { asyncImage in
                    switch asyncImage {
                    case .success(let img):
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipped()
                            .cornerRadius(8)
                    case .failure(_):
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                // File preview
                VStack(spacing: 2) {
                    Image(systemName: image.fileType.systemIcon)
                        .font(.system(size: 16))
                        .foregroundColor(softBlue)
                    
                    if let fileName = image.fileName {
                        Text(fileName)
                            .font(.system(size: 7))
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 50, height: 50)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            
            Button(action: {
                vm.removeImage(image)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
    }
}