//
//  AirchatApp.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import SwiftUI
import AppKit
import Foundation

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
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel?
    var menu: NSMenu!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize API key securely
        KeychainHelper.shared.setInitialAPIKey()
        
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set up the button
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: "Airchat")
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
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出 Airchat", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Store menu but don't assign it yet
        self.menu = menu
        
        // Create the floating panel
        makePanel()
    }
    
    @objc private func showPanel() {
        guard let panel = panel else { return }
        
        // Position panel near status bar
        if let button = statusItem.button {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = button.window?.convertToScreen(buttonRect) ?? .zero
            
            // Default to expanded size, SwiftUI will handle the collapsed size automatically
            let panelRect = NSRect(
                x: screenRect.midX - 180, // Center horizontally under button
                y: screenRect.minY - 530, // Position below button
                width: 360,
                height: 520
            )
            
            panel.setFrame(panelRect, display: true)
        }
        
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.contentView)
        NSApp.activate(ignoringOtherApps: true)
        
        // Apply mask after window is shown and sized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateWindowMaskForCurrentState()
        }
    }
    
    @objc private func toggleMenu() {
        guard let button = statusItem.button else { return }
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    
    private func makePanel() {
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
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
        
        // Make hosting view completely transparent
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
        panel.makeFirstResponder(panel.contentView)
    }
    
    // Observe window frame changes to update mask
    private func observeWindowFrameChanges() {
        guard let panel = panel else { return }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { _ in
            self.updateWindowMaskForCurrentState()
        }
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
    
    // Floato solution: Apply window-level corner mask
    private func applyWindowMask(cornerRadius: CGFloat = 20) {
        guard let panel = panel, let contentView = panel.contentView else { return }
        
        // Ensure contentView has layer
        contentView.wantsLayer = true
        
        DispatchQueue.main.async {
            let windowFrame = contentView.bounds
            guard windowFrame.width > 0 && windowFrame.height > 0 else { return }
            
            // Create rounded rect path with specified corner radius
            let path = NSBezierPath(roundedRect: windowFrame, xRadius: cornerRadius, yRadius: cornerRadius)
            
            // Create CAShapeLayer as mask
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            
            // Apply mask to content view layer
            if let layer = contentView.layer {
                layer.mask = shapeLayer
                layer.masksToBounds = true
            }
        }
    }
}
