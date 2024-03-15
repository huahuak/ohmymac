//
//  RencentWindow.swift
//  ohmymac
//
//  Created by huahua on 2024/3/10.
//

import Foundation
import AppKit

var rwm: Any?

func startRecentWindowManger() {
    rwm = RecentWindowManager()
}

class RecentWindowManager {
    var observer: AXObserver?
    var wsas: [WindowSwitchAction] = []
    var rwsas: [WindowSwitchAction] = []
    let wss: WindowSwitchShortcut = {
        var wss = WindowSwitchShortcut()
        WindowSwitchShortcut.startCGEvent(wss: &wss)
        return wss
    }()
    
    init() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(self, selector: #selector(addWSA(notification:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(addWSA(notification:)), name: NSWorkspace.didUnhideApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appWillLaunch(notification:)), name: NSWorkspace.willLaunchApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(removeWSA(notification:)), name: NSWorkspace.didHideApplicationNotification, object: nil)
        NSWorkspace.shared.runningApplications.forEach({ app in
            if app.isHidden { return }
            global.async {
                let axApp = AXUIElementCreateApplication(app.processIdentifier)
                if let axWin = WindowAction.getSingleWindowElement(axApp) {
                    main.async { [self] in
                        app.icon?.size = NSSize(width: 22, height: 22)
                        let icon = app.icon ?? randomIcon()
                        // for debug
                        if app.icon == nil {
                            openQuickLook(file: writeTmp(content: app.localizedName ?? "unkown app")!)
                        }
                        // end for debug
                        let wsa = WindowSwitchAction(icon, windowElement: axWin, application: app)
                        wsas.append(wsa)
                        menu.show(wsa.btn)
                    }
                }
            }
        })
        deInitFunc.append {
            notificationCenter.removeObserver(self)
        }
    }
    
    @objc func addWSA(notification: Notification) {
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        var frontMostWindow = WindowAction.getFrontMostWindow()
        if frontMostWindow == nil {
            Thread.sleep(forTimeInterval: 0.2)
            frontMostWindow = WindowAction.getFrontMostWindow()
        }
        guard let frontMostWindow = frontMostWindow else {
            debugPrint("get front most window failed"); return
        }
        // check
        if activatedApp.localizedName == "ohmymac" {
            return
        }
        var toRemove: [WindowSwitchAction] = []
        wsas.forEach({ it in
            if WindowAction.getSingleWindowElement(
                AXUIElementCreateApplication(it.app.processIdentifier)) == nil {
                toRemove.append(it)
            }
        })
        toRemove.forEach { remove in menu.clean(remove.btn); rwsas.append(remove) }
        wsas.removeAll(where: { it in toRemove.contains(where: { remove in remove.app == it.app }) })
        // swap
        if let wsa = wsas.first(where: {wsa in wsa.app == activatedApp}) {
            wsas.removeAll(where: {wsa in wsa.app == activatedApp})
            wsas.append(wsa)
            wsa.winEle = frontMostWindow
            menu.show(wsa.btn)
            return
        }
        // append
        if let wsa = rwsas.first(where: { it in it.app == activatedApp}) {
            rwsas.removeAll(where: { it in it.app == activatedApp})
            wsas.append(wsa)
            menu.show(wsa.btn)
        } else {
            activatedApp.icon?.size = NSSize(width: 22, height: 22)
            let icon = activatedApp.icon ?? randomIcon()
            // for debug
            if activatedApp.icon == nil {
                openQuickLook(file: writeTmp(content: activatedApp.localizedName ?? "unkown app")!)
            }
            // end for debug
            let wsa = WindowSwitchAction(icon, windowElement: frontMostWindow, application: activatedApp)
            wsas.append(wsa)
            menu.show(wsa.btn)
        }
    }
    
    @objc func appWillLaunch(notification: Notification) {
        Thread.sleep(forTimeInterval: 1)
        addWSA(notification: notification)
    }
    
    @objc func removeWSA(notification: Notification) {
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        if let wsa = wsas.first(where: {wsa in wsa.app == activatedApp}) {
            rwsas.append(wsa)
            menu.clean(wsa.btn)
            wsas.removeAll(where: {wsa in wsa.app == activatedApp})
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
        print(app.localizedName! + " is created.")
    }
    
    deinit {
        print((app.localizedName ?? "unkown app") + " is removed")
    }
    
    @objc func switchWindow(_ sender: NSButton) {
        let wsa = sender.target as! WindowSwitchAction
        wsa.app.activate()
        let windowElement = wsa.winEle
        AXUIElementSetAttributeValue(windowElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(windowElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        return
    }
}

class WindowSwitchShortcut {
    
    var doing = false
    var cnt = 1
    static func get (_ idx: Int) -> NSButton {
        let reverse = menu.view.subviews.count - 1 - (idx % menu.view.subviews.count)
        return menu.view.arrangedSubviews[reverse] as! NSButton
    }
    let start:() -> Void =  {
        menu.showAll()
        get(1).highlight(true)
    }
    let next: (_ idx: Int)->Void =  {idx in
        get(idx - 1).highlight(false)
        get(idx).highlight(true)
    }
    let end: (_ idx: Int) -> Void =  { idx in
        get(idx - 1).highlight(false)
        get(idx).performClick(get(idx))
    }
    
    static func startCGEvent(wss: inout WindowSwitchShortcut) {
        func myCGEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
            let wss = Unmanaged<WindowSwitchShortcut>.fromOpaque(refcon!).takeUnretainedValue()
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if !wss.doing && keyCode == 48 && event.flags.contains(.maskCommand) { // cmd + tab
                wss.doing = true
                wss.start()
                return nil
            }
            if wss.doing && keyCode == 48 && event.flags.contains(.maskCommand) {
                wss.cnt += 1
                wss.next(wss.cnt)
                return nil
            }
            if wss.doing && !event.flags.contains(.maskCommand) {
                wss.doing = false
                wss.end(wss.cnt)
                wss.cnt = 1
                return nil
            }

            return Unmanaged.passUnretained(event)
        
        }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let userInfo = Unmanaged.passUnretained(wss).toOpaque()
        guard let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                               place: .headInsertEventTap,
                                               options: .defaultTap,
                                               eventsOfInterest: CGEventMask(eventMask),
                                               callback: myCGEventCallback,
                                               userInfo: userInfo) else {
            print("failed to create event tap")
            exit(1)
        }
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
//        CFRunLoopRun()
    }
}


