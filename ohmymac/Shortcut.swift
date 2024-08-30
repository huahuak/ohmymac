//
//  Shortcut.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/25.
//

import Cocoa

import Foundation
import Carbon

func startShortcut() {
    initShortcut()
}


fileprivate func initShortcut() {
    // translate
    Hotkey().doubleTrigger(keyCode: .option, modifiers: .shift, handler: translate)
}

func percentExec(_ width: Double, _ height: Double = 1) -> Fn {
    return {
        guard let frontMostWindow = WindowCommand.getFrontMostWindow() else {
            debugPrint("get front most window failed"); return
        }
        WindowCommand.percent(frontMostWindow, widthPercent: width, heightPercent: height)
    }
}
