//
//  AnimationPerformanceMonitor.swift
//  Airchat
//
//  Created by Claude on 2025/6/26.
//

import Foundation
import QuartzCore

class AnimationPerformanceMonitor {
    static let shared = AnimationPerformanceMonitor()
    
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount = 0
    private var accumulatedFrameTime: CFTimeInterval = 0
    private let targetFrameTime: CFTimeInterval = 1.0 / 60.0 // 60 FPS
    
    private init() {}
    
    func startMonitoring() {
        lastFrameTime = CACurrentMediaTime()
        frameCount = 0
        accumulatedFrameTime = 0
    }
    
    func recordFrame() {
        let currentTime = CACurrentMediaTime()
        let frameTime = currentTime - lastFrameTime
        
        accumulatedFrameTime += frameTime
        frameCount += 1
        
        // 检测掉帧
        if frameTime > targetFrameTime * 1.5 {
            #if DEBUG
            print("⚠️ 动画掉帧检测: \(String(format: "%.1f", frameTime * 1000))ms (目标: \(String(format: "%.1f", targetFrameTime * 1000))ms)")
            #endif
        }
        
        // 每60帧报告一次平均性能
        if frameCount >= 60 {
            let averageFrameTime = accumulatedFrameTime / Double(frameCount)
            let averageFPS = 1.0 / averageFrameTime
            
            #if DEBUG
            print("📊 动画性能: 平均 \(String(format: "%.1f", averageFPS)) FPS, 平均帧时间 \(String(format: "%.1f", averageFrameTime * 1000))ms")
            #endif
            
            frameCount = 0
            accumulatedFrameTime = 0
        }
        
        lastFrameTime = currentTime
    }
    
    func stopMonitoring() {
        lastFrameTime = 0
        frameCount = 0
        accumulatedFrameTime = 0
    }
}