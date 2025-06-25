//
//  WindowManager.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/21.
//

import Foundation
import AppKit

final class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    weak var appDelegate: AppDelegate?
    
    private init() {}
    
    func toggleWindow() {
        guard let panel = appDelegate?.panel else { 
            print("WindowManager: Panel is nil!")
            return 
        }
        
        if panel.isVisible {
            print("WindowManager: Hiding window")
            appDelegate?.saveWindowPosition()
            panel.orderOut(nil)
        } else {
            print("WindowManager: Showing window")
            appDelegate?.showPanel()
        }
    }
    
    func showWindow() {
        appDelegate?.showPanel()
    }
    
    func hideWindow() {
        appDelegate?.saveWindowPosition()
        appDelegate?.panel?.orderOut(nil)
    }
    
    func toggleWindowState(collapsed: Bool) {
        appDelegate?.toggleWindowState(collapsed: collapsed)
    }
}