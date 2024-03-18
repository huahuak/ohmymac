//
//  AppDelegate.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/23.
//

import Cocoa
import Foundation
import UserNotifications


class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        requestAccessibilityPermission()
        setupCrashHandler()
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { granted, error in
            if granted {
                print("Notification authorization granted")
            } else {
                print("Notification authorization denied")
            }
        }
    }
    
    func setupCrashHandler() {
        NSSetUncaughtExceptionHandler { exception in
            _ = writeTmp(content: exception.callStackSymbols.joined(separator: "\n"))
        }
    }
}
