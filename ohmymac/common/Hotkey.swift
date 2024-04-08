//
//  Shortcut.swift
//  ohmymac
//
//  Created by huahua on 2024/4/2.
//

import Foundation
import AppKit

fileprivate let allFlags: [NSEvent.ModifierFlags] = [.shift, .option, .command, .function, .control]

class Hotkey {
    private var triggerTime: Double = 0
    private let interval = 0.2
    
    init() {}
    
    func doubleTrigger(modifiers: NSEvent.ModifierFlags, handler: @escaping Fn) {
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [self] event in
            if !event.modifierFlags.contains(modifiers) { return }
            for flag in allFlags.filter({ $0 != modifiers }) {
                if event.modifierFlags.contains(flag) {
                    triggerTime  = 0
                    return
                }
            }
            let now = event.timestamp
            if now - triggerTime < interval {
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
