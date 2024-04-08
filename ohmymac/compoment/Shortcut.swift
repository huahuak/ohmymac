//
//  Shortcut.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/25.
//

import Cocoa
import Atomics
import HotKey

import Foundation
import Carbon


// COMMENT:
// Shorcut compoment is used to listen shortcut keydown, then call some function and ui to response.

func startShortcut() {
    initShortcut()
    deInitFunc.append {
        hotkeys.removeAll()
    }
}

var hotkeys = [HotKey]()

fileprivate func initShortcut() {
    // window action
    add(HotKey(key: .l, modifiers: [.option]), percentExec(0.75, 0.85))
    add(HotKey(key: .semicolon, modifiers: [.option]), percentExec(0.75))
    add(HotKey(key: .quote, modifiers: [.option]), percentExec(0.9))
    add(HotKey(key: .m, modifiers: [.option]), percentExec(1))
    add(HotKey(key: .c, modifiers: [.option]), {
        guard let front = WindowAction.getFrontMostWindow() else {
            debugPrint("get front most window failed, can't center window "); return
        }
        WindowAction.center(front)
    })
    // translate
    Hotkey().doubleTrigger(modifiers: .option, handler: translate)
    // googleSearch
    add(HotKey(key: .g, modifiers: [.option, .command]), googleSearch)
}

// MARK: - internal function
func add(_ hotkey: HotKey, _ handler: @escaping Fn) {
    hotkey.keyDownHandler = { main.async { handler() } } 
    hotkeys.append(hotkey)
}


func percentExec(_ width: Double, _ height: Double = 1) -> Fn {
    return {
        guard let frontMostWindow = WindowAction.getFrontMostWindow() else {
            debugPrint("get front most window failed"); return
        }
        WindowAction.percent(frontMostWindow, widthPercent: width, heightPercent: height)
    }
}
