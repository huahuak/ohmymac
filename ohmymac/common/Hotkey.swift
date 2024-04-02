//
//  Shortcut.swift
//  ohmymac
//
//  Created by huahua on 2024/4/2.
//

import Foundation
import AppKit

class Hotkey {
    var triggerTime: Int64 = 0
    
    init() {}
    
    func doubleTrigger(modifiers: NSEvent.ModifierFlags, handler: @escaping Fn) {
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [self] event in
            if !event.modifierFlags.contains(modifiers) { return }
            let now = getCurrentTimestampInMilliseconds()
            if now - triggerTime < 200 { // trigger double
                main.async { handler() }
            }
            triggerTime = now
        }) {
            deInitFunc.append {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
