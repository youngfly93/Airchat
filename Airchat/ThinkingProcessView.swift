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
    
    // External data
    let reasoning: String
    var onComplete: (() -> Void)?
    var isDemo: Bool = false // 是否为演示模式
    var isStreaming: Bool = false // 是否为流式模式
    
    // 定义柔和的蓝色主题
    private let softBlue = Color(red: 0.4, green: 0.6, blue: 0.9)
    
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
        VStack(alignment: .leading, spacing: 10) {
            // 标题和计时器
            headerView
            
            // 思考过程滚动区域
            thinkingScrollView
        }
        .padding(12)
        .background(
            // 毛玻璃背景层
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .withinWindow
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                // 柔和色彩覆盖层
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(softBlue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(softBlue.opacity(0.15), lineWidth: 0.5)
                    )
            )
        )
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
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(spacing: 8) {
            // 思考图标（带动画）
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(softBlue)
                .scaleEffect(isCompleted ? 1.0 : 1.2)
                .animation(
                    isCompleted ? .none : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isCompleted
                )
            
            // 计时器文本
            Text(isCompleted ? "思考完成" : "思考中 \(elapsedTime)s")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isCompleted ? .secondary : softBlue)
            
            Spacer()
            
            // 状态指示器
            if !isCompleted {
                ProgressView()
                    .scaleEffect(0.7)
                    .progressViewStyle(CircularProgressViewStyle(tint: softBlue))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
            }
        }
    }
    
    // MARK: - Thinking Scroll View
    private var thinkingScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(displayedThoughts) { thought in
                        thoughtBubble(thought.text)
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
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 120) // 限制最大高度，更矮以增强滚动感
            .mask(
                // 渐变遮罩，增强朦胧感
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.1),
                        .init(color: .black, location: 0.9),
                        .init(color: .clear, location: 1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onChange(of: displayedThoughts.count) { _, _ in
                // 每当有新的思考内容添加时，自动滚动到底部
                withAnimation(.easeOut(duration: 0.25)) {
                    if let lastThought = displayedThoughts.last {
                        proxy.scrollTo(lastThought.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Thought Bubble
    private func thoughtBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 思考点图标
            Circle()
                .fill(softBlue.opacity(0.4))
                .frame(width: 6, height: 6)
                .padding(.top, 6)
                .opacity(0.8) // 增加朦胧感
            
            // 思考文本
            Text(text)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.primary.opacity(0.85)) // 增加朦胧感
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.horizontal, 4)
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
    
    // 递归添加句子，带延迟效果
    private func addSentencesWithDelay(_ sentences: [String], index: Int) {
        guard index < sentences.count, !sentences[index].isEmpty else { return }
        
        let segment = ThoughtSegment(text: sentences[index])
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            displayedThoughts.append(segment)
        }
        
        // 继续处理下一个句子
        if index + 1 < sentences.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
        thoughtTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            guard currentThoughtIndex < demoThoughts.count else {
                completeThinking()
                return
            }
            
            let thoughtText = demoThoughts[currentThoughtIndex]
            let segment = ThoughtSegment(text: thoughtText)
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                displayedThoughts.append(segment)
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
        
        // 逐段显示思考内容
        thoughtTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            guard currentThoughtIndex < paragraphs.count else {
                completeThinking()
                return
            }
            
            let thoughtText = paragraphs[currentThoughtIndex]
            let segment = ThoughtSegment(text: thoughtText)
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                displayedThoughts.append(segment)
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