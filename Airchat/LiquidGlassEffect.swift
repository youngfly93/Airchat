//
//  LiquidGlassEffect.swift
//  Airchat
//
//  Created by Claude on 2025/7/6.
//

import SwiftUI

// MARK: - Glass Effect Configuration
struct GlassConfiguration {
    var intensity: GlassIntensity = .regular
    var tint: Color? = nil
    var isInteractive: Bool = false
    var isEnabled: Bool = true
    
    // 预定义的色调
    static let blueTint = GlassConfiguration(tint: Color.blue.opacity(0.3))
    static let greenTint = GlassConfiguration(tint: Color.green.opacity(0.3))
    static let purpleTint = GlassConfiguration(tint: Color.purple.opacity(0.3))
}

enum GlassIntensity {
    case ultraThin
    case thin
    case regular
    case thick
    case ultraThick
    
    var blurRadius: CGFloat {
        switch self {
        case .ultraThin: return 10
        case .thin: return 20
        case .regular: return 30
        case .thick: return 40
        case .ultraThick: return 50
        }
    }
    
    var opacity: Double {
        switch self {
        case .ultraThin: return 0.3
        case .thin: return 0.5
        case .regular: return 0.7
        case .thick: return 0.8
        case .ultraThick: return 0.9
        }
    }
}

// MARK: - Liquid Glass View Modifier
struct LiquidGlassEffect: ViewModifier {
    let configuration: GlassConfiguration
    let shape: AnyShape
    
    @State private var animationPhase: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    
    init(configuration: GlassConfiguration = GlassConfiguration(), in shape: some Shape = RoundedRectangle(cornerRadius: 16)) {
        self.configuration = configuration
        self.shape = AnyShape(shape)
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if configuration.isEnabled {
                        glassBackground
                    } else {
                        Color.clear
                    }
                }
            )
            .clipShape(shape)
            .overlay(
                shape
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.3 : 0.5),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    @ViewBuilder
    private var glassBackground: some View {
        ZStack {
            // 基础模糊层
            shape
                .fill(.ultraThinMaterial)
                .blur(radius: configuration.intensity.blurRadius * 0.5)
            
            // 主玻璃效果层
            shape
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            baseColor.opacity(configuration.intensity.opacity),
                            baseColor.opacity(configuration.intensity.opacity * 0.7)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: configuration.intensity.blurRadius * 0.3)
            
            // 液体流动效果层（使用噪点模拟）
            if configuration.isInteractive {
                shape
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.1),
                                Color.clear,
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(1.0 + sin(animationPhase) * 0.02)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                            animationPhase = .pi * 2
                        }
                    }
            }
            
            // 高光层
            shape
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.3), location: 0),
                            .init(color: Color.clear, location: 0.5)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .blur(radius: 2)
        }
    }
    
    private var baseColor: Color {
        if let tint = configuration.tint {
            return tint
        }
        return colorScheme == .dark ? Color.black : Color.white
    }
}

// MARK: - Convenient View Extensions
extension View {
    func liquidGlass(
        _ intensity: GlassIntensity = .regular,
        in shape: some Shape = RoundedRectangle(cornerRadius: 16),
        tint: Color? = nil,
        isInteractive: Bool = false,
        isEnabled: Bool = true
    ) -> some View {
        let config = GlassConfiguration(
            intensity: intensity,
            tint: tint,
            isInteractive: isInteractive,
            isEnabled: isEnabled
        )
        return self.modifier(LiquidGlassEffect(configuration: config, in: shape))
    }
    
    func liquidGlass(configuration: GlassConfiguration, in shape: some Shape = RoundedRectangle(cornerRadius: 16)) -> some View {
        self.modifier(LiquidGlassEffect(configuration: configuration, in: shape))
    }
}

// MARK: - Glass Effect Container
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        content
            .environment(\.defaultMinListRowHeight, spacing)
    }
}

// MARK: - Shape Type Erasure
struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Namespace Support for Animations
extension View {
    func liquidGlassID<ID: Hashable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        self
            .matchedGeometryEffect(id: "liquidGlass_\(id)", in: namespace)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: id)
    }
}