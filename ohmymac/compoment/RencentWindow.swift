//
//  RencentWindow.swift
//  ohmymac
//
//  Created by huahua on 2024/3/10.
//

import Foundation
import AppKit

var wsas: [WindowSwitchAction] = []

class WindowSwitchListener {
    init() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(self, selector: #selector(windowDidSwitch(notification:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appWillLaunch(notification:)), name: NSWorkspace.willLaunchApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(windowDidClose(notification:)), name: NSWorkspace.didHideApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(windowDidClose(notification:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }
    
    @objc func windowDidSwitch(notification: Notification) {
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        Thread.sleep(forTimeInterval: 0.2)
        guard let frontMostWindow = WindowAction.getFrontMostWindow() else {
            debugPrint("get front most window failed"); return
        }
        // check
        if activatedApp.localizedName == "ohmymac" {
            return
        }
        if let old = wsas.last {
            let apple = AXUIElementCreateApplication(old.app.processIdentifier)
            let allW = WindowAction.getAllWindowElement(apple)
            let notMin = allW?.filter({ w in
                !WindowAction.isWindowMinimized(window: w)
            }).count
            if notMin == 0 {
                let wsa = wsas.removeLast()
                menu.clean(wsa.btn)
            }
            if old.app.localizedName == "Finder" && allW!.count - notMin! < 2 {
                menu.clean(old.btn)
            }
        }
        // swap
        if let wsa = wsas.first(where: {wsa in wsa.app == activatedApp}) {
            wsas.removeAll(where: {wsa in wsa.app == activatedApp})
            wsas.append(wsa)
            wsa.winEle = frontMostWindow
            menu.show(wsa.btn)
            return
        }
        // append
        activatedApp.icon?.size = NSSize(width: 22, height: 22)
        let wsa = WindowSwitchAction(activatedApp.icon!, windowElement: frontMostWindow, application: activatedApp)
        wsas.append(wsa)
        menu.show(wsa.btn)
    }
    
    @objc func appWillLaunch(notification: Notification) {
        Thread.sleep(forTimeInterval: 1)
        windowDidSwitch(notification: notification)
    }
    
    @objc func windowDidClose(notification: Notification) {
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        if let wsa = wsas.first(where: { wsa in wsa.app == activatedApp}) {
            wsas.removeAll(where: { wsa in wsa.app == activatedApp})
            menu.clean(wsa.btn)
        }
    }
}

class WindowSwitchAction {
    let btn: NSButton
    var winEle: AXUIElement
    let app: NSRunningApplication
    
    init(_ img: NSImage, windowElement: AXUIElement, application: NSRunningApplication) {
        btn = createMenuButton(img)
        winEle = windowElement
        app = application
        btn.target = self
        btn.action = #selector(switchWindow(_:))
//        print("create WindowSwitchAction for " + (app.localizedName ?? "unkown app"))
    }
    
    deinit {
        print("dead")
    }
    
    @objc func switchWindow(_ sender: NSButton) {
        let wsa = sender.target as! WindowSwitchAction
        wsa.app.activate()
        let windowElement = wsa.winEle
        AXUIElementSetAttributeValue(windowElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(windowElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(windowElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    }
}

