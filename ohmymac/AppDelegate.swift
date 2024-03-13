//
//  AppDelegate.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/23.
//

import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        requestAccessibilityPermission()
//        startWindowAction()
        startShortcut()
        startRecentWindowManger()
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        deInitFunc.forEach({ $0() })
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if trusted {
            debugPrint("Accessibility permission granted.")
        } else {
            debugPrint("Accessibility permission denied.")
            // @todo send a notification
            exit(ErrCode.NoPermission)
        }
    }
}
