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

var windowManager: WindowManager! = nil

func startWindowMenuManager() {
    windowManager = WindowManager()
    
    Hotkey().doubleTrigger(modifiers: .shift) {
        if let app = NSWorkspace.shared.frontmostApplication,
           let mainWindow = AXUIElementCreateApplication(app.processIdentifier).getMainWindow(),
           let window = windowManager.findWindow({ $0.windowID == mainWindow.windowID() }) {
               window.pin()
        }
    } // pin window shortcut
}


class WindowManager {
    let wss: WindowSwitchShortcut = {
        var wss = WindowSwitchShortcut()
        WindowSwitchShortcut.startCGEvent(wss: &wss)
        return wss
    }()
    var applications: [Application] = []
    
    
    init() {
        // ------------------------------------ //
        // init status
        // ----------------------------------- //
        let appendWindowFunc = { [self] (nsapp: NSRunningApplication, redo: Bool) in
            if nsapp.localizedName == "ohmymac" { return }
            if nsapp.localizedName == "Finder" { return }
            if applications.contains(where: { nsapp.processIdentifier == $0.nsApp.processIdentifier }) {
                return
            }
            let axApp = AXUIElementCreateApplication(nsapp.processIdentifier)
            retry {
                guard var axWindows = axApp.getAllWindows() else {
                    if redo { throw ErrCode.RetryErr };
                    return
                }
                if axWindows.count == 0 {
                    if let window = axApp.getMainWindow() { axWindows.append(window) }
                    if let window = axApp.getFocusedWindow() { axWindows.append(window) }
                    if axWindows.count == 0 {
                        if redo { throw ErrCode.RetryErr };
                        return
                    }
                }
                let app = Application(app: nsapp)
                applications.append(app)
                main.async {
                    axWindows.forEach{
                        guard let window = Window(app: app, axWindow: $0) else { return }
                        app.appendWindow(window)
                    }
                }
            }
        }
        NSWorkspace.shared.runningApplications.forEach({ nsapp in
            if nsapp.isHidden { return }
            global.async { appendWindowFunc(nsapp, false) }
        })
        observe(NSWorkspace.didTerminateApplicationNotification) { [self] nsapp in
            applications.removeAll{ $0.nsApp.processIdentifier == nsapp.processIdentifier }
        }
        observe(NSWorkspace.didActivateApplicationNotification) { [self] nsapp in
            appendWindowFunc(nsapp, true) // add when application not found.
            if let active = findApplication(nsapp) {
                active.notifyActivate()
                applications.filter{ !$0.eq(nsapp) }.forEach{ $0.minimizeAll() } // minimize other application
            }
            
        }
        observe(NSWorkspace.didHideApplicationNotification) { [self] nsapp in
            findApplication(nsapp)?.notifyHidden()
        }
        observe(NSWorkspace.didUnhideApplicationNotification) { [self] nsapp in
            appendWindowFunc(nsapp, false)
            findApplication(nsapp)?.notifyShown()
        }
        Observer.addGlobally(notice: NSWorkspace.activeSpaceDidChangeNotification) { [self] _ in
            applications.forEach {
                $0.notifyShown()
            }
        }
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
