//
//  WindowMenuManager.swift
//  ohmymac
//
//  Created by huahua on 2024/3/31.
//

import Foundation
import AppKit
import Cocoa
import HotKey

var windowManager: WindowManager? = nil

func startWindowMenuManager() {
    windowManager = WindowManager()
}


class WindowManager {
    let wss: WindowSwitchShortcut = {
        var wss = WindowSwitchShortcut()
        WindowSwitchShortcut.startCGEvent(wss: &wss)
        return wss
    }()
    var applications: [Application] = []
    
    // status
    var lastActiveWindowWeakRef: WindowCond? = nil
    
    
    init() {
        let initApplicationFunc = { [self] (nsapp: NSRunningApplication) in
            if nsapp.localizedName == "ohmymac" { return }
            if applications.contains(where: { nsapp.processIdentifier == $0.nsApp.processIdentifier }) {
                return
            }
            let axApp = AXUIElementCreateApplication(nsapp.processIdentifier)
            guard let axWindows = try WindowManager.getAllWindow(axApp) else { return }
            let app = Application(app: nsapp)
            applications.append(app)
            main.async {
                axWindows.forEach{
                    guard let window = Window(app: app, axWindow: $0) else { return }
                    app.appendWindow(window)
                }
            }
        }
        
        // init status
        NSWorkspace.shared.runningApplications.forEach({ nsapp in
            if nsapp.isHidden { return }
            global.async {
                retry(f: { try initApplicationFunc(nsapp) }, times: 1)
            }
        })
        
        /// Design Philosophy:
        /// - When window unhide/activate: append applicatoin icon to menubar.
        observe(NSWorkspace.didActivateApplicationNotification) { [self] nsapp in
            retry { try initApplicationFunc(nsapp) }
            if let active = findApplication(nsapp) {
                active.notifyActivate(axWindow: nil)
            }
        }
        observe(NSWorkspace.didUnhideApplicationNotification) { [self] nsapp in
            retry { try initApplicationFunc(nsapp) } // add when application not found.
            findApplication(nsapp)?.notifyShown()
        }
        
        /// - When window hide/close: remove application icon from menubar.
        observe(NSWorkspace.didTerminateApplicationNotification) { [self] nsapp in
            applications.removeAll{ $0.nsApp.processIdentifier == nsapp.processIdentifier }
        }
        observe(NSWorkspace.didHideApplicationNotification) { [self] nsapp in
            findApplication(nsapp)?.notifyHidden()
        }
        
        /// - When space changed, we need to update window status.
//        Observer.addGlobally(notice: NSWorkspace.activeSpaceDidChangeNotification) { [self] _ in
//        }
    }
    
    // ------------------------------------ //
    // MARK: notification
    // ----------------------------------- //
    static func notifyWindowActivated(_ cond: WindowCond) {
        guard let windowManager = windowManager else { return }
        guard let window = windowManager.findWindow(cond) else { return }
        guard let _ = window.app else { return }
        
        // check window
        if let windowDead = windowManager.findWindow({
            $0.axWindow.windowTitle() == nil
        }) {
            windowDead.app?.notifyWindowClosed(windowDead.cond)
        }
        
    }
    
    
    // ------------------------------------ //
    // MARK: helper function
    // ----------------------------------- //
    func findApplication(_ nsapp: NSRunningApplication) -> Application? {
        applications.first(where: { $0.nsApp.processIdentifier == nsapp.processIdentifier })
    }
    
    func findWindow(_ cond: WindowCond) -> Window? {
        for app in applications {
            if let window = app.findWindow(cond) {
                return window
            }
        }
        return nil
    }
    
    /// getAllWindow will try find window that is belongs to application
    /// if failed, getAllWindow() will throw RetryErr
    static func getAllWindow(_ axApp: AXUIElement) throws -> [AXUIElement]?  {
        guard var axWindows = axApp.getAllWindows() else {
            throw ErrCode.RetryErr
        }
        if axWindows.count == 0 {
            if let window = axApp.getMainWindow() { axWindows.append(window); return axWindows }
            if let window = axApp.getFocusedWindow() { axWindows.append(window); return axWindows }
            if axWindows.count == 0 {
                throw ErrCode.RetryErr
            }
        }
        return axWindows
    }
}

extension WindowManager {
    func observe(_ notices: NSNotification.Name..., handler: @escaping (NSRunningApplication) -> Void) {
        notices.forEach {
            Observer.addGlobally(notice: $0) { notification in
                guard let nsapp = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                        as? NSRunningApplication else { return }
                handler(nsapp)
            }
        }
    }
}


class WindowSwitchShortcut {
    
    var doing = false
    var cnt = 1
    var eventTap: CFMachPort?
    
    static func get (_ idx: Int) -> NSButton? {
        if menu.view.subviews.isEmpty { return nil }
        let reverse = menu.view.subviews.count - 1 - (idx % menu.view.subviews.count)
        return menu.view.arrangedSubviews[reverse] as? NSButton
    }
    let start:() -> Void =  {
        menu.showAll()
        main.async {
            Thread.sleep(forTimeInterval: 0.1)
            if let btn = get(1) {
                animate(shakeButton: btn)
            }
        }
        get(1)?.highlight(true)
    }
    let next: (_ idx: Int)->Void =  {idx in
        get(idx - 1)?.highlight(false)
        if let selected = get(idx) {
            selected.highlight(true)
            animate(shakeButton: selected)
        }
    }
    let end: (_ idx: Int) -> Void =  { idx in
        get(idx - 1)?.highlight(false)
        if let selected = get(idx) {
            selected.highlight(true)
            if let window = selected.target as? Window {
                main.async {
                    Thread.sleep(forTimeInterval: 0.2)
                    window.focus()
                }
            }
        }
    }
    
    private static func animate(shakeButton: NSButton) {
        shakeButton.layer?.removeAllAnimations()
        let shakeAnimation = CABasicAnimation(keyPath: "position")
        shakeAnimation.duration = 0.07
        shakeAnimation.repeatCount = 2
        shakeAnimation.autoreverses = true
        let fromPoint = CGPoint(x: shakeButton.frame.origin.x, y: shakeButton.frame.origin.y + 2)
        let toPoint = CGPoint(x: shakeButton.frame.origin.x, y: shakeButton.frame.origin.y - 2)
        shakeAnimation.fromValue = NSValue(point: fromPoint)
        shakeAnimation.toValue = NSValue(point: toPoint)
        shakeButton.layer?.add(shakeAnimation, forKey: "position")
    }
    
    static func startCGEvent(wss: inout WindowSwitchShortcut) {
        func myCGEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
            let wss = Unmanaged<WindowSwitchShortcut>.fromOpaque(refcon!).takeUnretainedValue()
            if type == .tapDisabledByTimeout {
                notify(msg: "cmd+tab shortcut was disabled by timeout!\nnow restart...")
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
