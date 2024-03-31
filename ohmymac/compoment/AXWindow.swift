//
//  AXWindow.swift
//  ohmymac
//
//  Created by huahua on 2024/3/31.
//

import Foundation
import Cocoa
import Carbon


class AXWindow {
    static func isAlive(window: AXUIElement) -> Bool {
        var isWindowAlive: Bool = false
        var windowValue: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &windowValue) == .success {
            if windowValue != nil {
                isWindowAlive = true
            }
        }
        return isWindowAlive
    }
}
