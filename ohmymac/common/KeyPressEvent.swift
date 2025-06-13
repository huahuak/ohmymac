//
//  KeyPressEvent.swift
//  ohmymac
//
//  Created by Hua on 2024/11/25.
//

import Foundation
import Cocoa

func pressKey(keyCode: KeyCode, mask: NSEvent.ModifierFlags? = nil) {
    let source = CGEventSource(stateID: .hidSystemState)
    let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
    let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
    if let mask = mask {
        keyDownEvent?.flags = CGEventFlags(rawValue: uint64(mask.rawValue))
        keyUpEvent?.flags = CGEventFlags(rawValue: uint64(mask.rawValue))
    }
    keyDownEvent?.post(tap: .cghidEventTap)
    keyUpEvent?.post(tap: .cghidEventTap)
}
