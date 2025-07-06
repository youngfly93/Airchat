# Liquid Glass 实现计划

## 调研总结

### 什么是 Liquid Glass？
Liquid Glass 是 Apple 在 WWDC 2025 引入的全新视觉设计语言，主要特点：
- 模拟玻璃的光学特性和液体的流动性
- 创建轻量、动态的材质效果
- 支持高级动画和形态变换
- 具有振动色彩适应性

### 核心实现方式
1. **基础实现**: 使用 `.glassEffect()` 修饰符
2. **自定义形状**: `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))`
3. **添加色调**: `.glassEffect(.regular.tint(.blue.opacity(0.4)))`
4. **交互模式**: `.glassEffect(.regular.interactive)`
5. **动画支持**: 使用 `@Namespace` 和 `glassEffectID` 实现流畅过渡

## 当前项目分析

### 现有毛玻璃效果位置
项目中使用了两种毛玻璃效果：
1. **NSVisualEffectView**: 通过 `VisualEffectView.swift` 封装的原生 macOS 效果
2. **SwiftUI Material**: 使用 `.regularMaterial` 和 `.ultraThinMaterial`

### 需要替换的位置（ChatWindow.swift）
- 第 184 行：折叠输入框背景
- 第 348、365 行：模型选择器背景  
- 第 558 行：展开视图主背景
- 第 634、989 行：图片预览背景（ultraThinMaterial）
- 第 762 行：发送按钮背景
- 第 788 行：展开输入框背景
- 第 932 行：设置按钮背景

## 实施计划

### 第一阶段：创建 Liquid Glass 组件
1. 创建 `LiquidGlassEffect.swift` 封装 Liquid Glass 效果
2. 实现基础配置选项（形状、色调、交互性）
3. 创建便捷修饰符以简化使用

### 第二阶段：渐进式替换
1. **输入框区域**（优先级：高）
   - 折叠输入框（第 184 行）
   - 展开输入框（第 788 行）
   - 使用交互式 glass effect

2. **按钮和控件**（优先级：中）
   - 发送按钮（第 762 行）
   - 设置按钮（第 932 行）
   - 使用带色调的 glass effect

3. **容器背景**（优先级：中）
   - 主聊天窗口背景（第 558 行）
   - 模型选择器背景（第 348、365 行）
   - 使用标准 glass effect

4. **辅助元素**（优先级：低）
   - 图片预览背景（第 634、989 行）
   - 使用轻量级 glass effect

### 第三阶段：动画优化
1. 实现窗口展开/折叠的 glass 形态变换
2. 添加 namespace 和 glassEffectID
3. 优化过渡动画效果

### 第四阶段：性能优化
1. 使用 GlassEffectContainer 管理多个 glass 效果
2. 优化渲染性能
3. 处理动态内容背景适应

## 注意事项
1. Liquid Glass 需要 iOS 26 / macOS Tahoe，可能需要条件编译
2. 保持向后兼容性，为旧系统保留毛玻璃效果
3. 注意性能影响，特别是在动画密集的场景
4. 保持设计一致性，避免过度使用效果

## 预期效果
- 更加生动、流畅的视觉体验
- 更好的内容适应性和可读性
- 流畅的形态变换动画
- 现代化的设计语言