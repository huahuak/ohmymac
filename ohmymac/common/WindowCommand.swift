//
//  WindowAction.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/24.
//

import Cocoa


class WindowCommand {
    static func percent(_ axWindow: AXUIElement, widthPercent: Double, heightPercent: Double = 1) {
        guard let screen = NSScreen.screens.first?.visibleFrame else {
            debugPrint("centerWindow: get screen failed!")
            return
        }
        
        let adjustX = round(screen.size.width * (1 - widthPercent) / 2)
        let adjustY = round(screen.size.height * (1 - heightPercent) / 2)
        let point = CGPoint(x: adjustX, y: adjustY)
        
        let width = round(screen.size.width * widthPercent)
        let height = round(screen.size.height * heightPercent)
        let size = CGSize(width: width, height: height)
        
        axWindow.move(point: point)
        axWindow.resize(size: size)
    }
    
    static func center(_ axWindow: AXUIElement) {
        guard let screen = NSScreen.screens.first?.visibleFrame else {
            return
        }
        guard let currentWindowSize = axWindow.windowSize() else {
            return
        }
        let adjustX = (screen.size.width - currentWindowSize.width) / 2.0
        let adjustY = (screen.size.height - currentWindowSize.height) / 2.0
        let point = CGPoint(x: adjustX, y: adjustY)
        axWindow.move(point: point)
    }
 
    static func getFrontMostWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axuiApp = AXUIElementCreateApplication(app.processIdentifier)
        return axuiApp.focusedWindow()
    }
}
