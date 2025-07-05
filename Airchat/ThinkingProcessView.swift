//
//  ThinkingProcessView.swift
//  Airchat
//
//  Created by Claude on 2025/6/30.
//

import SwiftUI

struct ThinkingProcessView: View {
    // MARK: - Properties
    @State private var elapsedTime: Int = 0
    @State private var displayedThoughts: [ThoughtSegment] = []
    @State private var currentThoughtIndex = 0
    @State private var isCompleted = false
    @State private var timer: Timer?
    @State private var thoughtTimer: Timer?
    @State private var lastProcessedLength = 0 // 用于跟踪已处理的文本长度
    @State private var activeThoughtId: UUID? = nil // 当前活跃段落的ID
    
    // External data
    let reasoning: String
    var onComplete: (() -> Void)?
    var isDemo: Bool = false // 是否为演示模式
    var isStreaming: Bool = false // 是否为流式模式
    
    // 定义深色主题 - 针对毛玻璃背景优化对比度
    private let darkBlue = Color(red: 0.05, green: 0.1, blue: 0.15)
    private let contrastBlue = Color(red: 0.2, green: 0.3, blue: 0.5)
    
    // MARK: - Data Models
    struct ThoughtSegment: Identifiable {
        let id = UUID()
        let text: String
        let timestamp: Date = Date()
    }
    
    // 演示用的思考过程数据
    private let demoThoughts: [String] = [
        "正在分析用户的问题...",
        "思考可能的解决方案...",
        "评估不同方法的优缺点...",
        "构建基础逻辑框架...",
        "考虑边界情况和异常处理...",
        "优化性能和用户体验...",
        "验证方案的可行性...",
        "准备生成最终回答..."
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 优化的标题栏
            headerView

            // 优化的思考过程滚动区域
            thinkingScrollView
        }
        .padding(10)
        .background(optimizedBackground)
        .onAppear {
            startThinking()
        }
        .onDisappear {
            stopThinking()
        }
        .onChange(of: reasoning) { _, newValue in
            // 监听reasoning文本的变化，用于流式更新
            if isStreaming && !isDemo {
                processStreamingUpdate(newValue)
            }
        }
        .onChange(of: isStreaming) { _, newValue in
            // 监听流式状态变化，当从true变为false时，表示思考完成
            if !newValue && !isCompleted {
                completeThinking()
            }
        }
    }

    // MARK: - Optimized UI Components
    private var headerView: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .scaleEffect(isCompleted ? 1.0 : 1.1)
                .animation(
                    isCompleted ? .none : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isCompleted
                )

            Text(isCompleted ? "思考完成" : "思考中...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            if !isCompleted {
                ProgressView()
                    .scaleEffect(0.6)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.8)))
            }
        }
    }

    private var thinkingScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(displayedThoughts) { thought in
                        thoughtBubble(thought)
                            .id(thought.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    // 底部哨兵，确保滚动到最新内容
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 120)
            .mask(optimizedGradientMask)
            .onChange(of: displayedThoughts.count) { _, _ in
                // 优化滚动动画 - 使用更快速的弹簧动画
                withAnimation(.interpolatingSpring(stiffness: 400, damping: 25)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private func thoughtBubble(_ thought: ThoughtSegment) -> some View {
        let isActive = activeThoughtId == thought.id

        return HStack(alignment: .top, spacing: 5) {
            // 优化的指示器
            Circle()
                .fill(.white.opacity(isActive ? 1.0 : 0.7))
                .frame(width: isActive ? 6 : 4, height: isActive ? 6 : 4)
                .padding(.top, 4)
                .animation(.interpolatingSpring(stiffness: 600, damping: 30), value: isActive)

            // 优化的文本渲染
            Text(thought.text)
                .font(.system(size: 11, weight: isActive ? .medium : .regular))
                .foregroundColor(.white.opacity(isActive ? 1.0 : 0.9))
                .multilineTextAlignment(.leading)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.interpolatingSpring(stiffness: 600, damping: 30), value: isActive)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
    }

    /// 优化的渐变遮罩，减少GPU负担
    private var optimizedGradientMask: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.2),
                .init(color: .black, location: 0.8),
                .init(color: .clear, location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 优化的背景渲染
    private var optimizedBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        darkBlue.opacity(0.95),
                        contrastBlue.opacity(0.9)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(contrastBlue.opacity(0.3), lineWidth: 0.5)
            )
    }



    // MARK: - Thinking Logic
    private func startThinking() {
        guard !isCompleted else { return }
        
        // 启动计时器
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
        
        if isDemo {
            // 演示模式：使用预设的思考内容
            startDemoMode()
        } else if isStreaming {
            // 流式模式：等待实时数据更新
            // 初始化处理状态
            lastProcessedLength = 0
            if !reasoning.isEmpty {
                processStreamingUpdate(reasoning)
            }
        } else {
            // 静态模式：处理传入的reasoning文本
            processReasoningText()
            // 如果不是流式模式，说明已经完成，直接标记为完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completeThinking()
            }
        }
    }
    
    // 处理流式更新
    private func processStreamingUpdate(_ newReasoning: String) {
        guard !isCompleted else { return }
        
        // 检查是否有新内容
        let newLength = newReasoning.count
        guard newLength > lastProcessedLength else { return }
        
        // 提取新增的内容
        let newContent = String(newReasoning.suffix(newLength - lastProcessedLength))
        lastProcessedLength = newLength
        
        // 将新内容按句子或短语分割
        let sentences = extractSentences(from: newContent)
        
        // 使用递归延迟添加句子，创造流式效果
        addSentencesWithDelay(sentences, index: 0)
    }
    
    // 递归添加句子，带延迟效果 - 优化版本
    private func addSentencesWithDelay(_ sentences: [String], index: Int) {
        guard index < sentences.count, !sentences[index].isEmpty else { return }

        let segment = ThoughtSegment(text: sentences[index])

        // 使用更快速的弹簧动画，减少阻尼感
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 20)) {
            displayedThoughts.append(segment)
            // 设置新段落为活跃状态
            activeThoughtId = segment.id
        }

        // 减少高亮持续时间，提高响应速度
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if activeThoughtId == segment.id {
                withAnimation(.easeOut(duration: 0.2)) {
                    activeThoughtId = nil
                }
            }
        }

        // 减少延迟时间，提高流畅度
        if index + 1 < sentences.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                addSentencesWithDelay(sentences, index: index + 1)
            }
        }
    }
    
    // 提取句子或短语
    private func extractSentences(from text: String) -> [String] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 按标点符号和换行符分割
        let separators: [String] = ["。", "!", "？", ".", "?", "!", "\n"]
        var sentences: [String] = [cleaned]
        
        for separator in separators {
            sentences = sentences.flatMap { sentence in
                sentence.components(separatedBy: separator)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }
        
        return sentences
    }
    
    private func startDemoMode() {
        thoughtTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in // 加快演示速度
            guard currentThoughtIndex < demoThoughts.count else {
                completeThinking()
                return
            }

            let thoughtText = demoThoughts[currentThoughtIndex]
            let segment = ThoughtSegment(text: thoughtText)

            // 使用更快速的弹簧动画
            withAnimation(.interpolatingSpring(stiffness: 400, damping: 20)) {
                displayedThoughts.append(segment)
                // 设置新段落为活跃状态
                activeThoughtId = segment.id
            }

            // 减少高亮持续时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if activeThoughtId == segment.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        activeThoughtId = nil
                    }
                }
            }

            currentThoughtIndex += 1
        }
    }
    
    private func processReasoningText() {
        // 将reasoning文本分割成段落
        let paragraphs = reasoning
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !paragraphs.isEmpty else {
            completeThinking()
            return
        }
        
        // 逐段显示思考内容 - 优化版本
        thoughtTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in // 加快显示速度
            guard currentThoughtIndex < paragraphs.count else {
                completeThinking()
                return
            }

            let thoughtText = paragraphs[currentThoughtIndex]
            let segment = ThoughtSegment(text: thoughtText)

            // 使用更快速的弹簧动画
            withAnimation(.interpolatingSpring(stiffness: 400, damping: 20)) {
                displayedThoughts.append(segment)
                // 设置新段落为活跃状态
                activeThoughtId = segment.id
            }

            // 减少高亮持续时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if activeThoughtId == segment.id {
                    withAnimation(.easeOut(duration: 0.15)) {
                        activeThoughtId = nil
                    }
                }
            }

            currentThoughtIndex += 1
        }
    }
    
    private func completeThinking() {
        stopThinking()
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isCompleted = true
        }
        
        // 调用完成回调
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete?()
        }
    }
    
    private func stopThinking() {
        timer?.invalidate()
        timer = nil
        thoughtTimer?.invalidate()
        thoughtTimer = nil
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // 演示模式
        ThinkingProcessView(
            reasoning: "",
            onComplete: {
                print("Demo thinking completed!")
            },
            isDemo: true,
            isStreaming: false
        )
        
        // 真实模式示例
        ThinkingProcessView(
            reasoning: """
            我需要仔细分析这个问题的各个方面。

            首先，让我理解用户的核心需求是什么。

            然后，我会考虑可能的解决方案。

            接下来，我需要评估每种方案的优缺点。

            最后，我会选择最合适的方案并提供详细的实现步骤。
            """,
            onComplete: {
                print("Real thinking completed!")
            },
            isDemo: false,
            isStreaming: false
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}