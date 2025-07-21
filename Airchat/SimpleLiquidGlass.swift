//
//  SimpleLiquidGlass.swift
//  Airchat
//
//  Created by Claude on 2025/7/6.
//  基于官方 SwiftUI .glassEffect() API 的简化实现
//

import SwiftUI

// MARK: - Glass Intensity Configuration
enum GlassIntensity {
    case ultraThin
    case thin
    case regular
    case thick
    case ultraThick
}

// MARK: - Simple Glass Effect Modifier
struct SimpleLiquidGlass: ViewModifier {
    let cornerRadius: CGFloat
    let intensity: GlassIntensity
    let tint: Color?
    
    init(cornerRadius: CGFloat = 16, intensity: GlassIntensity = .regular, tint: Color? = nil) {
        self.cornerRadius = cornerRadius
        self.intensity = intensity
        self.tint = tint
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .background(.regularMaterial)
                    .if(tint != nil) { view in
                        view.overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(tint!.opacity(0.1))
                        )
                    }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Future-Ready Glass Effect (iOS 26+)
// Note: .glassEffect() is not yet available in current SwiftUI
// This is prepared for future iOS 26 / macOS 15 when the API becomes available
/*
@available(iOS 26.0, macOS 15.0, *)
struct FutureGlassEffect: ViewModifier {
    let cornerRadius: CGFloat
    let intensity: GlassIntensity
    let tint: Color?
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
            )
            .glassEffect() // 使用官方 API
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
*/

// MARK: - Conditional View Extension
extension View {
    // For now, just use the simple implementation
    // Will be updated when .glassEffect() becomes available
    func conditionalGlassEffect(
        cornerRadius: CGFloat = 16,
        intensity: GlassIntensity = .regular,
        tint: Color? = nil
    ) -> some View {
        // Currently only use custom implementation
        self.modifier(SimpleLiquidGlass(
            cornerRadius: cornerRadius,
            intensity: intensity,
            tint: tint
        ))
    }
    
    // 简化的 glass 效果方法
    func simpleGlass(
        cornerRadius: CGFloat = 16,
        intensity: GlassIntensity = .regular,
        tint: Color? = nil
    ) -> some View {
        self.modifier(SimpleLiquidGlass(
            cornerRadius: cornerRadius,
            intensity: intensity,
            tint: tint
        ))
    }
}

// MARK: - Helper Extension for Conditional Modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Glass Button Style
struct GlassButtonStyle: ButtonStyle {
    let cornerRadius: CGFloat
    let tint: Color?
    
    init(cornerRadius: CGFloat = 12, tint: Color? = nil) {
        self.cornerRadius = cornerRadius
        self.tint = tint
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .simpleGlass(cornerRadius: cornerRadius, tint: tint)
    }
}

// MARK: - Button Style Extension
extension ButtonStyle where Self == GlassButtonStyle {
    static func glass(cornerRadius: CGFloat = 12, tint: Color? = nil) -> GlassButtonStyle {
        GlassButtonStyle(cornerRadius: cornerRadius, tint: tint)
    }
}