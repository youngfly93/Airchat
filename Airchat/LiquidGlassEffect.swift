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
    
    // 预定义的色调 - 更加透明
    static let blueTint = GlassConfiguration(tint: Color.blue.opacity(0.1))
    static let greenTint = GlassConfiguration(tint: Color.green.opacity(0.1))
    static let purpleTint = GlassConfiguration(tint: Color.purple.opacity(0.1))
}

enum GlassIntensity {
    case ultraThin
    case thin
    case regular
    case thick
    case ultraThick
    
    var blurRadius: CGFloat {
        switch self {
        case .ultraThin: return 8
        case .thin: return 12
        case .regular: return 16
        case .thick: return 20
        case .ultraThick: return 25
        }
    }
    
    var opacity: Double {
        switch self {
        case .ultraThin: return 0.6
        case .thin: return 0.75
        case .regular: return 0.9
        case .thick: return 1.0
        case .ultraThick: return 1.2
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
                // 玻璃边缘高光
                shape
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.6 : 0.8),
                                Color.white.opacity(0.2),
                                Color.clear,
                                Color.white.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .overlay(
                // 内边缘阴影
                shape
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.black.opacity(0.1),
                                Color.black.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
                    .offset(x: 0.5, y: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private var glassBackground: some View {
        ZStack {
            // 1. 背景模糊层（模拟玻璃后的背景扭曲）
            shape
                .fill(.regularMaterial)
                .opacity(0.6)
                .blur(radius: configuration.intensity.blurRadius)
            
            // 2. 玻璃基础层（带轻微色调）
            shape
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            baseColor.opacity(configuration.intensity.opacity * 0.3),
                            baseColor.opacity(configuration.intensity.opacity * 0.15),
                            Color.clear
                        ]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
            
            // 3. 玻璃反射层（模拟环境反射）
            shape
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.25), location: 0),
                            .init(color: Color.white.opacity(0.05), location: 0.4),
                            .init(color: Color.clear, location: 0.7),
                            .init(color: Color.white.opacity(0.1), location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 2)
            
            // 4. 边缘高光（玻璃边缘的光线折射）
            shape
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.4), location: 0),
                            .init(color: Color.clear, location: 0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 0.5)
            
            // 5. 液体流动效果（交互时的动态反射）
            if configuration.isInteractive {
                shape
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.1 + Foundation.sin(animationPhase) * 0.05),
                                Color.clear,
                                Color.white.opacity(0.05 + Foundation.cos(animationPhase) * 0.02)
                            ]),
                            startPoint: UnitPoint(
                                x: 0.5 + Foundation.sin(animationPhase) * 0.2,
                                y: 0.5 + Foundation.cos(animationPhase) * 0.2
                            ),
                            endPoint: UnitPoint(
                                x: 0.5 - Foundation.sin(animationPhase) * 0.2,
                                y: 0.5 - Foundation.cos(animationPhase) * 0.2
                            )
                        )
                    )
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: false)) {
                            animationPhase = .pi * 2
                        }
                    }
            }
            
            // 6. 顶层光泽（模拟玻璃表面的镜面反射）
            shape
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.15), location: 0),
                            .init(color: Color.clear, location: 0.15)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
        }
    }
    
    private var baseColor: Color {
        if let tint = configuration.tint {
            return tint
        }
        // 使用极其微妙的中性灰色，几乎透明
        return colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)
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