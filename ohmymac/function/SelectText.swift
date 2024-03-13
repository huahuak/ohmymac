//
//  SelectText.swift
//  ohmymac
//
//  Created by huahua on 2024/3/14.
//

import Foundation
import Cocoa

typealias Fn4String = (String) -> Void

func getScreenText(doFn: @escaping Fn4String) {
    func executeCopy() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        keyDownEvent?.flags = .maskCommand
        keyUpEvent?.flags = .maskCommand
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    func getClipBordText() -> String? {
        let clipboardText = NSPasteboard.general.string(forType: .string)
        return clipboardText
    }
    
    executeCopy()
    global.async {
        Thread.sleep(forTimeInterval: 0.05)
        let text = getClipBordText() ?? "NO TEXT FOUND!"
        main.async { doFn(text) }
    }
}
