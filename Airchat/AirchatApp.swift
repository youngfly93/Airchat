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
    private let collapsedSize = NSSize(width: 60, height: 60)
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
            if let image = NSImage(named: "MenuIcon") {
                image.size = NSSize(width: 20, height: 20)
                // 不设置为 template，保持原始颜色
                button.image = image
            } else {
                // 备用方案：使用系统图标
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
        
        // 确保窗口处于展开状态
        if isCollapsed {
            isCollapsed = false
            let expandedFrame = NSRect(
                x: panel.frame.origin.x,
                y: panel.frame.origin.y,
                width: expandedSize.width,
                height: expandedSize.height
            )
            panel.setFrame(expandedFrame, display: false)
            NotificationCenter.default.post(name: .windowStateChanged, object: nil, userInfo: ["isCollapsed": false])
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
            guard let screen = NSScreen.main else {
                return NSRect(x: 100, y: 100, width: 360, height: 520)
            }
            let screenFrame = screen.visibleFrame
            return NSRect(
                x: screenFrame.midX - 180,
                y: screenFrame.midY - 260,
                width: 360,
                height: 520
            )
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
        // Open Settings window
        if let settingsWindow = NSApp.windows.first(where: { $0.title == "Settings" || $0.title == "设置" }) {
            settingsWindow.makeKeyAndOrderFront(nil)
        } else {
            // Try to open settings using the Settings scene
            for window in NSApp.windows {
                if window.identifier?.rawValue == "com.apple.SwiftUI.Settings" {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
            }
            // If Settings window doesn't exist, use the menu command
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
    
    
    // 优化的窗口动画系统
    private var animationTimer: Timer?
    private var animationStartTime: CFTimeInterval = 0
    private var animationDuration: CFTimeInterval = 0.35
    private var startFrame = NSRect.zero
    private var targetFrame = NSRect.zero
    private var isAnimating = false
    
    func toggleWindowState(collapsed: Bool) {
        guard let panel = panel else { return }
        
        // 如果正在动画，先停止
        stopAnimation()
        
        isCollapsed = collapsed
        let targetSize = collapsed ? collapsedSize : expandedSize
        
        // 计算动画参数
        startFrame = panel.frame
        targetFrame = startFrame
        targetFrame.origin.x = startFrame.maxX - targetSize.width
        targetFrame.origin.y = startFrame.maxY - targetSize.height
        targetFrame.size = targetSize
        
        // 提前通知SwiftUI准备动画
        NotificationCenter.default.post(name: .windowStateChanged, object: nil, userInfo: ["isCollapsed": collapsed])
        
        // 使用Timer实现高帧率动画
        startTimerAnimation()
    }
    
    private func startTimerAnimation() {
        guard let panel = panel else { return }
        
        isAnimating = true
        animationStartTime = CACurrentMediaTime()
        
        // 开始性能监测
        AnimationPerformanceMonitor.shared.startMonitoring()
        
        // 创建高精度定时器（60fps = 16.67ms间隔）
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
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
        
        // 使用优化的缓动函数
        let easedProgress = easeInOutCubic(progress)
        
        // 计算插值frame
        let currentFrame = NSRect(
            x: lerp(startFrame.origin.x, targetFrame.origin.x, easedProgress),
            y: lerp(startFrame.origin.y, targetFrame.origin.y, easedProgress),
            width: lerp(startFrame.width, targetFrame.width, easedProgress),
            height: lerp(startFrame.height, targetFrame.height, easedProgress)
        )
        
        // 设置frame并保持视觉效果
        panel.setFrame(currentFrame, display: true, animate: false)
        
        // 动画完成
        if progress >= 1.0 {
            stopAnimation()
            // 最后更新mask
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
    
    // 优化的缓动函数
    private func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let p = 2 * t - 2
            return 1 + p * p * p / 2
        }
    }
    
    // 线性插值
    private func lerp(_ start: Double, _ end: Double, _ progress: Double) -> Double {
        return start + (end - start) * progress
    }
    
    private func makePanel() {
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: expandedSize.width, height: expandedSize.height),
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
        
        let currentFrame = panel.frame
        
        // Determine if collapsed based on window size
        // Collapsed: 60x60, Expanded: 360x520
        let isCollapsed = currentFrame.width <= 80 // Some tolerance
        let cornerRadius: CGFloat = isCollapsed ? 18 : 20
        
        applyWindowMask(cornerRadius: cornerRadius)
    }
    
    // 简化的窗口mask应用
    private func applyWindowMask(cornerRadius: CGFloat = 20) {
        guard let panel = panel, let contentView = panel.contentView else { return }
        
        DispatchQueue.main.async {
            // 只有在需要时才启用layer
            if !contentView.wantsLayer {
                contentView.wantsLayer = true
            }
            
            let windowFrame = contentView.bounds
            guard windowFrame.width > 0 && windowFrame.height > 0 else { return }
            
            // 创建简单的rounded rect mask
            let path = NSBezierPath(roundedRect: windowFrame, xRadius: cornerRadius, yRadius: cornerRadius)
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.fillRule = .evenOdd
            
            // 确保layer设置正确
            if let layer = contentView.layer {
                layer.mask = shapeLayer
                layer.masksToBounds = true
                layer.backgroundColor = NSColor.clear.cgColor
                layer.isOpaque = false
            }
        }
    }
}
