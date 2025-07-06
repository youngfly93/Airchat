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
        case .ultraThin: return 3
        case .thin: return 5
        case .regular: return 8
        case .thick: return 12
        case .ultraThick: return 16
        }
    }
    
    var opacity: Double {
        switch self {
        case .ultraThin: return 0.05
        case .thin: return 0.1
        case .regular: return 0.15
        case .thick: return 0.2
        case .ultraThick: return 0.25
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
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.25),
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.3
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var glassBackground: some View {
        ZStack {
            // 基础透明模糊层
            shape
                .fill(.ultraThinMaterial)
                .opacity(0.3)
            
            // 主玻璃效果层 - 几乎透明
            shape
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            baseColor.opacity(configuration.intensity.opacity),
                            baseColor.opacity(configuration.intensity.opacity * 0.5)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: configuration.intensity.blurRadius * 0.2)
            
            // 液体流动效果层（更轻微）
            if configuration.isInteractive {
                shape
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.02),
                                Color.clear,
                                Color.white.opacity(0.01)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(1.0 + sin(animationPhase) * 0.01)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                            animationPhase = .pi * 2
                        }
                    }
            }
            
            // 微妙高光层
            shape
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.1), location: 0),
                            .init(color: Color.clear, location: 0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .blur(radius: 1)
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