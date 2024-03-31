//
//  WindowMenuManager.swift
//  ohmymac
//
//  Created by huahua on 2024/3/31.
//

import Foundation
import AppKit

fileprivate var windowMenuManager: WindowMenuManager? = nil
fileprivate let openingWindow = OpeningWindow()

func startWindowMenuManager() {
    windowMenuManager = WindowMenuManager()
}

fileprivate class WindowMenuManager {
    let wss: WindowSwitchShortcut = {
        var wss = WindowSwitchShortcut()
        WindowSwitchShortcut.startCGEvent(wss: &wss)
        return wss
    }()
    
    init() {
        // init status
        NSWorkspace.shared.runningApplications.forEach({ app in
            if app.isHidden { return }
            let appendWindowFunc = {
                let axApp = AXUIElementCreateApplication(app.processIdentifier)
                if let axWin = WindowAction.getSingleWindowElement(axApp) {
                    let window = Window(app: app, axWindow: axWin)
                    main.async { openingWindow.append(window) }
                }
            }
            global.async { appendWindowFunc() }
        })
        // add event
        let addEvent = { (event: @escaping @Sendable (Notification) -> Void, notice: Notification.Name...) in
            notice.forEach({
                let observer = NSWorkspace.shared.notificationCenter
                    .addObserver(forName: $0, object: nil, queue: nil, using: event)
                deInitFunc.append({
                    NSWorkspace.shared.notificationCenter.removeObserver(observer)
                })
            })
        }
        let comingWindowHandler: @Sendable (Notification) -> Void = { notice in
            self.getWindowFromNotice(notice) {
                openingWindow.check()
                openingWindow.append($0)
            }
        }
        let removeWindowHandler: @Sendable (Notification) -> Void = { notice in
            self.getWindowFromNotice(notice) {
                openingWindow.remove($0)
            }
        }
        addEvent(
            comingWindowHandler,
            NSWorkspace.willLaunchApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification
        )
        addEvent(
            removeWindowHandler,
            NSWorkspace.didHideApplicationNotification
        )
    }
    
    func getWindowFromNotice(_ notification: Notification,
                             handler: (Window) -> Void) {
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        if activatedApp.localizedName == "ohmymac" { return }
        var frontMostWindow = WindowAction.getFrontMostWindow()
        if frontMostWindow == nil {
            Thread.sleep(forTimeInterval: 0.2)
            frontMostWindow = WindowAction.getFrontMostWindow()
        }
        guard let frontMostWindow = frontMostWindow else {
            debugPrint("get front most window failed"); return
        }
        handler(Window(app: activatedApp, axWindow: frontMostWindow))
    }
}

fileprivate class OpeningWindow {
    var windows: [Window] = []
    
    func append(_ window: Window) {
        if let exist = windows.first(where: { $0 == window }) {
            windows.removeAll(where: { $0 == exist })
            windows.append(exist)
            menu.show(exist.btn)
            return
        }
        windows.append(window)
        menu.show(window.btn)
    }
    
    func remove(_ window: Window) {
        windows.removeAll(where: { $0 == window })
        menu.clean(window.btn)
    }
    
    func check() {
        let deadWindow = windows.filter({ !AXWindow.isAlive(window: $0.axWindow) })
        deadWindow.forEach(remove)
    }
}

fileprivate class Window: Equatable {
    let axWindow: AXUIElement
    let app: NSRunningApplication
    lazy var btn: NSButton = {
        let img = app.icon
        img?.size = NSSize(width: 22, height: 22)
        let btn = createMenuButton(img ?? randomIcon())
        btn.target = self
        btn.action = #selector(switchWindow(_:))
        btn.sendAction(on: [.leftMouseUp])
        debugPrint(app.localizedName! + " ✅")
        return btn
    }()
    
    init(app: NSRunningApplication, axWindow: AXUIElement) {
        self.app = app
        self.axWindow = axWindow
    }
    
    @objc func switchWindow(_ sender: NSButton) {
        let activateWindow = {
            let window = sender.target as! Window
            AXUIElementSetAttributeValue(window.axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(window.axWindow, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            window.app.activate()
        }
        if let event = NSApp.currentEvent {
            activateWindow()
        }
    }
    
    static func == (lhs: Window, rhs: Window) -> Bool {
        return lhs.app == rhs.app /*&& lhs.axWindow == rhs.axWindow*/
    }
}

class WindowSwitchShortcut {
    
    var doing = false
    var cnt = 1
    var eventTap: CFMachPort?
    
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
            if type == .tapDisabledByTimeout {
                main.async {
                    notify(msg: "cmd+tab shortcut was disabled by timeout!\nnow restart...")
                }
                if let eventTap = wss.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                return nil
            }
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
            exit(ErrCode.Err)
        }
        wss.eventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
}
