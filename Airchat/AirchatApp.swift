//
//  AirchatApp.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import SwiftUI
import AppKit
import Foundation
import KeyboardShortcuts

extension Notification.Name {
    static let windowStateChanged = Notification.Name("windowStateChanged")
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        
        return path
    }
}

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

@main
struct AirchatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    static var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }
    
    init() {
        // 注册全局快捷键回调
        KeyboardShortcuts.onKeyUp(for: .toggleWindow) {
            WindowManager.shared.toggleWindow()
        }
    }
    
    var body: some Scene {
        Settings {
            TabView {
                // 快捷键设置
                VStack {
                    Text("快捷键设置")
                        .font(.headline)
                        .padding(.bottom, 10)
                    
                    KeyboardShortcuts.Recorder(
                        "展开/折叠浮窗:",
                        name: .toggleWindow
                    )
                    
                    Text("默认快捷键: ⌥ + Space")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
                .frame(width: 300, height: 150)
                .padding()
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
                }
                
                // API Key 设置
                APIKeySettingsView()
                    .tabItem {
                        Label("API Key", systemImage: "key.fill")
                    }
            }
            .frame(width: 400, height: 200)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel?
    var menu: NSMenu!
    private let windowPositionKey = "AirchatWindowPosition"
    private var hasRestoredPosition = false
    private var isCollapsed = false
    
    // 定义折叠和展开的尺寸
    private let collapsedSize = NSSize(width: 480, height: 64)  // 输入框尺寸
    private let expandedSize = NSSize(width: 360, height: 520)
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize API key securely
        KeychainHelper.shared.setInitialAPIKey()
        
        // Set WindowManager reference
        WindowManager.shared.appDelegate = self
        
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set up the button
        if let button = statusItem.button {
            // 🎨 使用白色版本的菜单栏图标，与其他应用保持一致
            if let image = NSImage(named: "MenuIconWhite") {
                // 调整菜单栏图标尺寸为 24x24，更符合系统标准
                image.size = NSSize(width: 24, height: 24)
                // 设置为 template 模式，让系统自动适配深色/浅色模式
                image.isTemplate = true
                button.image = image
            } else if let image = NSImage(named: "MenuIcon") {
                // 备用方案：使用原始图标
                image.size = NSSize(width: 24, height: 24)
                button.image = image
            } else {
                // 最后备用方案：使用系统图标
                button.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: "Airchat")
            }
            button.action = #selector(toggleMenu)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create menu
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let showChatItem = NSMenuItem(title: "打开聊天窗口", action: #selector(showPanel), keyEquivalent: "")
        showChatItem.target = self
        menu.addItem(showChatItem)
        
        let resetPositionItem = NSMenuItem(title: "重置窗口位置", action: #selector(resetWindowPosition), keyEquivalent: "")
        resetPositionItem.target = self
        menu.addItem(resetPositionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出 Airchat", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Store menu but don't assign it yet
        self.menu = menu
        
        // Create the floating panel
        makePanel()
    }
    
    @objc func showPanel() {
        guard let panel = panel else { 
            print("Panel is nil!")
            return 
        }
        
        // 如果是首次显示，确保状态同步
        if panel.frame.size == .zero || (!hasRestoredPosition && isCollapsed) {
            // 初始化为折叠状态
            isCollapsed = true
            NotificationCenter.default.post(name: .windowStateChanged, object: nil, userInfo: ["isCollapsed": true])
        }
        
        // Get the main screen bounds
        guard let screen = NSScreen.main else {
            print("No main screen found!")
            return
        }
        let screenFrame = screen.visibleFrame
        
        // Try to restore saved position
        if let savedPosition = UserDefaults.standard.string(forKey: windowPositionKey),
           hasRestoredPosition {
            // Use saved position if available and we've restored at least once
            let components = savedPosition.split(separator: ",")
            if components.count == 2,
               let x = Double(components[0]),
               let y = Double(components[1]) {
                var savedFrame = NSRect(x: x, y: y, width: panel.frame.width, height: panel.frame.height)
                
                // Ensure the window is within screen bounds
                if !screenFrame.contains(savedFrame) {
                    print("Saved position is off-screen, resetting to default")
                    savedFrame = getDefaultWindowPosition()
                }
                
                panel.setFrame(savedFrame, display: true)
                print("Restored window position: \(savedFrame)")
            }
        } else {
            // First time or no saved position - position near status bar
            let defaultFrame = getDefaultWindowPosition()
            panel.setFrame(defaultFrame, display: true)
            hasRestoredPosition = true
            print("Using default window position: \(defaultFrame)")
        }
        
        panel.makeKeyAndOrderFront(nil)
        // 不要让TextField成为第一响应者，避免显示焦点环
        panel.makeFirstResponder(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Apply mask after window is shown and sized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateWindowMaskForCurrentState()
        }
    }
    
    private func getDefaultWindowPosition() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 100, y: 100, width: isCollapsed ? 480 : 360, height: isCollapsed ? 64 : 520)
        }
        
        let screenFrame = screen.visibleFrame
        let windowSize = isCollapsed ? collapsedSize : expandedSize
        
        if isCollapsed {
            // 输入框模式：屏幕中央
            return NSRect(
                x: screenFrame.midX - windowSize.width / 2,
                y: screenFrame.midY - windowSize.height / 2, // 垂直居中
                width: windowSize.width,
                height: windowSize.height
            )
        } else {
            // 展开模式：原有逻辑
            if let button = statusItem.button {
                let buttonRect = button.convert(button.bounds, to: nil)
                let screenRect = button.window?.convertToScreen(buttonRect) ?? .zero
                
                return NSRect(
                    x: screenRect.midX - 180,
                    y: screenRect.minY - 530,
                    width: 360,
                    height: 520
                )
            } else {
                // Fallback to center of screen
                return NSRect(
                    x: screenFrame.midX - 180,
                    y: screenFrame.midY - 260,
                    width: 360,
                    height: 520
                )
            }
        }
    }
    
    @objc private func toggleMenu() {
        guard let button = statusItem.button else { return }
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }
    
    @objc private func quitApp() {
        // 清理动画资源
        stopAnimation()
        NSApplication.shared.terminate(nil)
    }
    
    deinit {
        // 确保DisplayLink被清理
        stopAnimation()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func resetWindowPosition() {
        // Clear saved position
        UserDefaults.standard.removeObject(forKey: windowPositionKey)
        hasRestoredPosition = false
        
        // If window is open, reposition it
        if let panel = panel, panel.isVisible {
            let defaultFrame = getDefaultWindowPosition()
            panel.setFrame(defaultFrame, display: true, animate: true)
            print("Reset window position to default: \(defaultFrame)")
        }
    }
    
    @objc private func openSettings() {
        // 简单的方法：直接使用 SwiftUI 的 Settings 场景
        DispatchQueue.main.async {
            // 查找是否已有设置窗口
            for window in NSApp.windows {
                if window.title.contains("设置") || window.title.contains("Settings") || window.identifier?.rawValue.contains("Settings") == true {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    return
                }
            }
            
            // 如果没有找到，尝试通过键盘快捷键打开
            let event = NSEvent.keyEvent(with: .keyDown, location: NSPoint.zero, modifierFlags: [.command], timestamp: 0, windowNumber: 0, context: nil, characters: ",", charactersIgnoringModifiers: ",", isARepeat: false, keyCode: 43)
            if let event = event {
                NSApp.postEvent(event, atStart: false)
            }
        }
    }
    
    
    // 优化的窗口动画系统
    private var animationTimer: Timer?
    private var animationStartTime: CFTimeInterval = 0
    private var animationDuration: CFTimeInterval = 0.2
    private var startFrame = NSRect.zero
    private var targetFrame = NSRect.zero
    private var isAnimating = false
    
    func toggleWindowState(collapsed: Bool) {
        guard let panel = panel else { return }
        
        // 如果已经是目标状态，直接返回
        if isCollapsed == collapsed {
            print("窗口已经是目标状态: \(collapsed ? "折叠" : "展开")")
            return
        }
        
        // 如果正在动画，先停止
        stopAnimation()
        
        isCollapsed = collapsed
        let targetSize = collapsed ? collapsedSize : expandedSize
        
        // 计算动画参数
        startFrame = panel.frame
        targetFrame = startFrame
        
        // 优化动画逻辑：保持底部位置固定，向上展开
        targetFrame.size = targetSize
        targetFrame.origin.x = startFrame.midX - targetSize.width / 2  // 水平居中
        // 保持底部位置固定：新窗口底部 = 原窗口底部
        targetFrame.origin.y = startFrame.origin.y + startFrame.height - targetSize.height
        
        // 🔧 修复：即时切换SwiftUI内容，使用线性动画同步
        // 立即通知内容切换，依靠更快的线性动画避免重叠
        NotificationCenter.default.post(name: .windowStateChanged, object: nil, userInfo: ["isCollapsed": collapsed])
        
        // 立即开始窗口尺寸动画
        startTimerAnimation()
    }
    
    private func startTimerAnimation() {
        guard let panel = panel else { return }
        
        isAnimating = true
        animationStartTime = CACurrentMediaTime()
        
        // 开始性能监测
        AnimationPerformanceMonitor.shared.startMonitoring()
        
        // 创建超高精度定时器（120fps = 8.33ms间隔）- 更丝滑的动画
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
        
        // 设置定时器优先级
        RunLoop.current.add(animationTimer!, forMode: .common)
        
        // 保持VisualEffectView兼容性
        panel.displaysWhenScreenProfileChanges = false
    }
    
    private func updateAnimation() {
        guard let panel = panel, isAnimating else {
            stopAnimation()
            return
        }

        // 记录帧性能
        AnimationPerformanceMonitor.shared.recordFrame()

        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - animationStartTime
        let progress = min(elapsed / animationDuration, 1.0)

        // 使用卷帘门效果的缓动函数 - 更接近线性但稍微柔和
        let easedProgress = easeInOutSine(progress)

        // 计算插值frame - 使用高精度插值确保丝滑过渡
        let currentFrame = NSRect(
            x: smoothLerp(startFrame.origin.x, targetFrame.origin.x, easedProgress),
            y: smoothLerp(startFrame.origin.y, targetFrame.origin.y, easedProgress),
            width: smoothLerp(startFrame.width, targetFrame.width, easedProgress),
            height: smoothLerp(startFrame.height, targetFrame.height, easedProgress)
        )

        // 设置frame并保持视觉效果
        panel.setFrame(currentFrame, display: true, animate: false)

        // 🔧 卷帘门效果：更频繁的遮罩更新确保平滑
        let frameCount = Int(progress * 60) // 基于60fps计算帧数
        if frameCount % 2 == 0 || progress >= 1.0 { // 每2帧更新一次，保持流畅
            updateWindowMaskForCurrentFrame(currentFrame)
        }

        // 动画完成
        if progress >= 1.0 {
            stopAnimation()
            // 最后确保遮罩正确
            updateWindowMaskForCurrentState()
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isAnimating = false
        
        // 停止性能监测
        AnimationPerformanceMonitor.shared.stopMonitoring()
        
        // 恢复正常的窗口设置
        panel?.displaysWhenScreenProfileChanges = true
    }
    
    // 卷帘门效果的缓动函数 - 接近线性但更柔和
    private func easeInOutSine(_ t: Double) -> Double {
        return -(cos(.pi * t) - 1) / 2
    }
    
    // 更丝滑的缓动函数 - 模拟自然的过渡效果
    private func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let p = 2 * t - 2
            return 1 + p * p * p / 2
        }
    }
    
    // 更丝滑的缓动函数 - 模拟窗帘下拉的自然物理效果
    private func easeOutQuart(_ t: Double) -> Double {
        let p = t - 1
        return 1 - p * p * p * p
    }

    // 备用的更平滑缓动函数
    private func easeInOutQuint(_ t: Double) -> Double {
        if t < 0.5 {
            return 16 * t * t * t * t * t
        } else {
            let p = 2 * t - 2
            return 1 + p * p * p * p * p / 2
        }
    }
    
    // 高精度平滑插值 - 减少动画抖动
    private func smoothLerp(_ start: Double, _ end: Double, _ progress: Double) -> Double {
        // 使用更高精度的计算，避免浮点数精度问题
        let diff = end - start
        let result = start + diff * progress

        // 对于非常小的变化，直接返回目标值避免抖动
        if abs(diff) < 0.01 && progress > 0.95 {
            return end
        }

        return result
    }

    // 标准线性插值（备用）
    private func lerp(_ start: Double, _ end: Double, _ progress: Double) -> Double {
        return start + (end - start) * progress
    }
    
    private func makePanel() {
        // 默认以折叠状态（输入框）开始
        isCollapsed = true
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: collapsedSize.width, height: collapsedSize.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        
        panel?.level = .floating
        panel?.isMovableByWindowBackground = true
        // Floato solution: 完全透明的窗口背景
        panel?.backgroundColor = .clear
        panel?.isOpaque = false
        panel?.hasShadow = false
        panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // 确保窗口可以接受鼠标事件和键盘输入
        panel?.acceptsMouseMovedEvents = true
        panel?.ignoresMouseEvents = false
        
        // Set up the SwiftUI content
        let contentView = NSHostingView(rootView: ChatWindow())
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // 确保VisualEffectView能正常工作
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.layer?.isOpaque = false
        
        panel?.contentView = contentView
        
        // Floato solution: Apply window-level corner mask and observe frame changes
        applyWindowMask()
        observeWindowFrameChanges()
        
        // Ensure no background drawing
        panel?.hidesOnDeactivate = false
        
        // 监听应用激活事件，确保窗口始终在前面
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // 监听其他应用激活事件
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(otherApplicationDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showPanel()
        }
        return true
    }
    
    @objc private func applicationDidBecomeActive() {
        bringPanelToFront()
    }
    
    @objc private func otherApplicationDidActivate() {
        // 当其他应用激活时，确保我们的面板仍然在前面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.bringPanelToFront()
        }
    }
    
    private func bringPanelToFront() {
        guard let panel = panel, panel.isVisible else { return }
        panel.level = .floating
        panel.orderFrontRegardless()
        
        // 确保窗口可以接受事件
        panel.makeKeyAndOrderFront(nil)
        // 不要让TextField成为第一响应者
        panel.makeFirstResponder(nil)
    }
    
    // Observe window frame changes to update mask and save position
    private func observeWindowFrameChanges() {
        guard let panel = panel else { return }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { _ in
            self.updateWindowMaskForCurrentState()
        }
        
        // Save position when window moves
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { _ in
            self.saveWindowPosition()
        }
    }
    
    func saveWindowPosition() {
        guard let panel = panel else { return }
        let position = "\(panel.frame.origin.x),\(panel.frame.origin.y)"
        UserDefaults.standard.set(position, forKey: windowPositionKey)
    }
    
    // Update mask based on current window size
    private func updateWindowMaskForCurrentState() {
        guard let panel = panel else { return }
        updateWindowMaskForCurrentFrame(panel.frame)
    }

    // 🔧 新增：根据当前frame实时更新遮罩
    private func updateWindowMaskForCurrentFrame(_ currentFrame: NSRect) {
        // Determine if collapsed based on window size
        // Collapsed: 480x64, Expanded: 360x520

        // 动态计算圆角半径，在动画过程中平滑过渡
        let collapsedRadius: CGFloat = 32
        let expandedRadius: CGFloat = 20

        let cornerRadius: CGFloat
        if currentFrame.width >= 480 {
            // 折叠状态或接近折叠状态
            cornerRadius = collapsedRadius
        } else if currentFrame.width <= 360 {
            // 展开状态或接近展开状态
            cornerRadius = expandedRadius
        } else {
            // 动画过程中，根据宽度插值计算圆角
            let progress = (currentFrame.width - 360) / (480 - 360)
            cornerRadius = expandedRadius + (collapsedRadius - expandedRadius) * progress
        }

        applyWindowMask(cornerRadius: cornerRadius)
    }
    
    // 优化的窗口mask应用 - 减少重建频率和视觉抖动
    private func applyWindowMask(cornerRadius: CGFloat = 20) {
        guard let panel = panel, let contentView = panel.contentView else { return }

        // 只有在需要时才启用layer
        if !contentView.wantsLayer {
            contentView.wantsLayer = true
        }

        let windowFrame = contentView.bounds
        guard windowFrame.width > 0 && windowFrame.height > 0 else { return }

        // 🔧 优化：复用现有的mask layer，只更新path，并添加平滑过渡
        if let layer = contentView.layer {
            let path = NSBezierPath(roundedRect: windowFrame, xRadius: cornerRadius, yRadius: cornerRadius)

            if let existingMask = layer.mask as? CAShapeLayer {
                // 🔧 关键修复：使用隐式动画让遮罩变化更平滑
                CATransaction.begin()
                CATransaction.setDisableActions(false) // 启用隐式动画
                CATransaction.setAnimationDuration(0.1) // 短暂的过渡动画
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))

                // 复用现有的mask layer，只更新path
                existingMask.path = path.cgPath

                CATransaction.commit()
            } else {
                // 首次创建mask layer
                let shapeLayer = CAShapeLayer()
                shapeLayer.path = path.cgPath
                shapeLayer.fillRule = .evenOdd

                layer.mask = shapeLayer
                layer.masksToBounds = true
                layer.backgroundColor = NSColor.clear.cgColor
                layer.isOpaque = false
            }
        }
    }
}
