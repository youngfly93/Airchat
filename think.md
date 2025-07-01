给 Claude 的需求模板 (macOS SwiftUI 版本)
你好，我正在开发一个 macOS 应用程序，需要你用 SwiftUI 框架帮我实现一个 UI 视图。这个视图的功能是实时展示一个 AI 的“思考过程”，效果如我之前提供的视频所示。

视图的核心目标： 创建一个名为 ThinkingProcessView.swift 的可复用 SwiftUI 视图。它能模拟并展示一个流式的、自动滚动的文本动画。

请遵循以下关键功能点来实现：

主容器: 视图应该有一个主容器，例如使用 VStack 或 ZStack，并带有圆角和背景色，形成一个“气泡”外观。

计时器:

当视图出现时，一个计时器 (Timer) 开始工作。

界面上需要有一个 Text 视图，格式为 "Thinking for X seconds"，其中 "X" 的值通过 @State 变量持有，并每秒递增。

流式文本展示区:

在计时器下方，需要有一个 ScrollView。

文本内容不是一次性显示的，而是逐段、逐句地动态添加到 ScrollView 中。

自动滚动功能 (最关键):

请务必使用 ScrollViewReader 来实现此功能。

在 ScrollView 中显示的每一行或每一段新文本都需要有一个唯一的、可追踪的 ID。

当新的文本内容被追加并显示出来后，立即使用 ScrollViewReader 的 scrollTo() 方法，将视图滚动到最新那段文本的 ID 所在的位置。这样就能确保最新的内容总是可见的。

数据模拟:

由于没有真实的后端接口，请在视图内部创建一个模拟的数据源。

可以创建一个 Swift 字符串数组，例如 let thoughts: [String] = ["正在分析需求...", "思考可能的实现方案...", "构建基础组件结构...", "编写计时器逻辑...", "实现自动滚动效果..."]。

使用一个 Timer (可以和计时器共用或另起一个) 每隔 1-2 秒从数组中取出一个字符串，并将其追加到一个用于驱动界面的 @State 字符串数组中。

完成状态:

当所有“思考”文本都显示完毕后，计时器需要停止 (timer.invalidate())。

可以提供一个回调闭包 var onComplete: (() -> Void)?，在过程结束后调用它，通知父视图思考已结束。

代码要求:

请提供一个完整的、可直接在 Xcode 项目中使用的 ThinkingProcessView.swift 文件。

请确保代码是结构清晰、可复用的 SwiftUI 视图。

在代码的关键部分，尤其是 ScrollViewReader 和 Timer 的使用逻辑处，添加必要的注释。

请使用 SwiftUI 的 @State 属性、Timer.publish、ScrollView 和 ScrollViewReader 来完整实现。

请为我生成最终的代码。

给你的额外建议
为什么是 SwiftUI: 之所以强烈推荐 SwiftUI，是因为它的声明式语法和 ScrollViewReader 等内置工具，就是为了解决这类动态 UI 更新和滚动问题而设计的，实现起来会比传统方法简单得多。

如果你的项目是 AppKit (Cocoa): 如果你维护的是一个旧的 AppKit 项目，你需要向 Claude 提出不同的要求，关键词会变成 NSScrollView 和 NSTextView。你需要告诉它：“请通过编程方式向 NSTextView 追加文本，并调用 scrollRangeToVisible(_:) 方法，确保新文本始终可见。” 这个过程比 SwiftUI 要繁琐一些。

直接复制粘贴: 你可以把上面模板里的内容直接复制给 Claude Code。它拥有关于 SwiftUI 的丰富知识，看到 ScrollViewReader、@State、Timer 这些关键词，就能准确理解你的意图。