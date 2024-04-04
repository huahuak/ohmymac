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

fileprivate typealias WindowCond = (Window) -> Bool

fileprivate var windowManager: WindowManager! = nil

func startWindowMenuManager() { // IMPORTANT: don't change init order!!!
    windowManager = WindowManager()
}

// ------------------------------------ //
// window function
// ----------------------------------- //
fileprivate func getAXWindowFromAXApp(axApp: AXUIElement) -> AXUIElement? {
    //    if let axWindow = AXWindow.getFocusedWindow(app: app) { return axWindow }
    if let axWindow = AXWindow.getMainWindow(app: axApp) { return axWindow }
    return nil
}

let pinWindowHandler = {
    if let app = NSWorkspace.shared.frontmostApplication {
        windowManager.notifyWindowPinned({ Window.cond(window: $0, app: app) })
    }
} // for shortcut

// ------------------------------------ //
// check
// ----------------------------------- //
fileprivate var checkHandler: [Fn] = []
fileprivate var check = { checkHandler.forEach({ $0() }) }

fileprivate class WindowManager {
    let wss: WindowSwitchShortcut = {
        var wss = WindowSwitchShortcut()
        WindowSwitchShortcut.startCGEvent(wss: &wss)
        return wss
    }()
    var shift = false
    // window event handler
    let openings = WindowCollection()
    let pins = WindowCollection()
    let fullscreen = WindowCollection()
    
    init() {
        // ------------------------------------ //
        // init status
        // ----------------------------------- //
        NSWorkspace.shared.runningApplications.forEach({ app in
            if app.isHidden { return }
            let appendWindowFunc = {
                let axApp = AXUIElementCreateApplication(app.processIdentifier)
                if let axWindow = getAXWindowFromAXApp(axApp: axApp) {
                    let window = Window(app: app, axWindow: axWindow)
                    main.async { self.notifyWindowCreated(window) }
                }
            }
            global.async { appendWindowFunc() }
        })
        // ------------------------------------ //
        // add observer
        // ----------------------------------- //
        addNSWorkSpaceObserver(
            { self.createWindowFromNotice($0, handler: self.notifyWindowCreated) },
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification
        )
        addNSWorkSpaceObserver(
            { [self] in
                var found = false
                extractCondFromNotice($0) { [self ]cond in
                    if findWindow(cond) == nil { return }
                    found = true
                    notifyWindowtFocused(cond)
                }
                if !found {
                    createWindowFromNotice($0, handler: self.notifyWindowCreated)
                }
                [openings, pins, fullscreen].forEach({ $0.check() })
            },
            NSWorkspace.didActivateApplicationNotification
        )
        addNSWorkSpaceObserver(
            { self.extractCondFromNotice($0, handler: self.notifyWindowRemoved) },
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        )
        let updateSpaceHandler: @Sendable (Notification) -> Void = { [self] _ in
            [openings, pins, fullscreen].flatMap({ $0.windows }).forEach({
                $0.updateSpace()
            })
        } // updateSpaceHandler
        addNSWorkSpaceObserver(
            updateSpaceHandler,
            NSWorkspace.activeSpaceDidChangeNotification
        )
        // ------------------------------------ //
        // add monitor
        // ----------------------------------- //
        addMonitor(.flagsChanged) { event in
            self.shift = event.modifierFlags.contains(.shift)
        }
    }
    
    // ------------------------------------ //
    // window function
    // ----------------------------------- //
    func notifyWindowCreated(_ window: Window) {
        self.openings.append(window)
        minimizeOtherWindowExcept(window.cond)
        [openings].forEach({ $0.syncUI() })
    }
    
    func notifyWindowRemoved(_ cond: WindowCond) {
        [openings, pins, fullscreen].forEach({
            $0.remove(cond)
        })
        [openings, pins, fullscreen].forEach({ $0.syncUI() })
    }
    
    func notifyWindowtFocused(_ cond: WindowCond) {
        [openings, pins].forEach({
            if $0.windows.contains(where: cond) {
                $0.update(cond)
                minimizeOtherWindowExcept(cond)
            }
        })
        if fullscreen.windows.contains(where: cond) {
            fullscreen.update(cond)
        } // if fullscreen window focused, don't minimize original window.
        [openings, pins, fullscreen].forEach({ $0.syncUI() })
    }
    
    func notifyWindowPinned(_ cond: WindowCond) {
        if fullscreen.windows.contains(where: cond) {
            return
        } // don't mark fullscreent app.
        guard let window = findWindow(cond) else { return }
        openings.remove(cond)
        pins.append(window); window.pin()
        [openings, pins].forEach({ $0.syncUI() })
    }
    
    func notifyWindowEnterFullscreen(_ cond: WindowCond) {
        guard let window = findWindow(cond) else { return }
        pins.remove(cond); window.unpin()
        openings.remove(cond)
        fullscreen.append(window)
        [openings, pins, fullscreen].forEach({ $0.syncUI() })
    }
    
    func notifyWindowExitFullscreen(_ cond: WindowCond) {
        guard let window = fullscreen.windows.first(where: cond) else { return }
        fullscreen.remove(cond)
        pins.append(window); window.pin()
        [fullscreen, pins].forEach({ $0.syncUI() })
    }
    
    func minimizeOtherWindowExcept(_ cond: WindowCond) {
        openings.currentSpaceWindow()
            .filter({ !cond($0) })
            .forEach({ window in
                if !AXWindow.minimize(window: window.axWindow) {
                    notify(msg: "minimize failed! \(String(describing: window.app.localizedName))")
                }
            })
    }
    
    func findWindow(_ cond: WindowCond) -> Window? {
        return [openings, pins, fullscreen]
            .flatMap({ $0.windows })
            .first(where: cond)
    }
    
    // ------------------------------------ //
    // helper function
    // ----------------------------------- //
    func addNSWorkSpaceObserver(_ handler: @escaping @Sendable (Notification) -> Void, _ notices: Notification.Name...) {
        notices.forEach({
            Observer.add(notice: $0) { notice in
                main.async { handler(notice) }
            }
        })
    }
    
    func addMonitor(_ flags: NSEvent.EventTypeMask, _ event: @escaping (NSEvent) -> Void) {
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: flags, handler: event) {
            deInitFunc.append {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
    
    func createWindowFromNotice(_ notification: Notification,
                                handler: @escaping (Window) -> Void) {
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        if activatedApp.localizedName == "ohmymac" { return }
        if activatedApp.localizedName == "Finder" { return }
        // TOOD Finder bug with GetID
        let axApp = AXUIElementCreateApplication(activatedApp.processIdentifier)
        var axWindow = getAXWindowFromAXApp(axApp: axApp)
        if axWindow == nil {
            Thread.sleep(forTimeInterval: 0.2)
            axWindow = getAXWindowFromAXApp(axApp: axApp)
        }
        guard let exist = axWindow else { return }
        handler(Window(app: activatedApp, axWindow: exist))
    }
    
    func extractCondFromNotice(_ notification: Notification,
                               handler: @escaping ((Window) -> Bool) -> Void) {
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        if activatedApp.localizedName == "ohmymac" { return }
        if activatedApp.localizedName == "Finder" { return }
        // TOOD Finder bug with GetID
        handler({ Window.cond(window: $0, app: activatedApp) })
    }
}

fileprivate class WindowCollection {
    var windows: [Window] = []
    var UIFunc: [Fn] = []
    
    init() {
        checkHandler.append(check)
    }
    
    func update(_ cond: WindowCond) {
        guard let exist = windows.first(where: cond) else {
            warn("WindoeSet update() failed!")
            return
        }
        remove(cond)
        windows.append(exist)
        UIFunc.append {
            menu.show(exist.btn)
        }
    }
    
    func append(_ window: Window) {
        remove(window.cond)
        windows.append(window)
        UIFunc.append {
            menu.show(window.btn)
        }
    }
    
    func remove(_ cond: WindowCond) {
        windows.filter(cond).forEach({ window in
            UIFunc.append { menu.clean(window.btn) }
        })
        windows.removeAll(where: cond)
    }
    
    func check() {
        let deadWindow = windows.filter({
            let axApp = AXUIElementCreateApplication($0.app.processIdentifier)
            return getAXWindowFromAXApp(axApp: axApp) == nil
        })
        deadWindow.forEach({ remove($0.cond) })
    }
    
    static let currentSpaceFilter = { (window: Window) in
        AXWindow.activatedSpaceID() ==
        AXWindow.getWindowSpaceID(window: window.axWindow)
    }
    
    func currentSpaceWindow() -> [Window] {
        return  windows.filter(WindowCollection.currentSpaceFilter)
    }
    
    func syncUI() {
        UIFunc.forEach({ $0() })
        UIFunc.removeAll()
    }
}

fileprivate class Window: Equatable {
    var axWindow: AXUIElement
    let app: NSRunningApplication
    var deinitCallback: [Fn] = []
    lazy var baseIcon = {
        let img = app.icon
        img?.size = NSSize(width: 22, height: 22)
        return img ?? randomIcon()
    }()
    lazy var btn: NSButton = {
        let btn = createMenuButton(self.baseIcon)
        btn.target = self
        btn.action = #selector(switchWindow(_:))
        btn.sendAction(on: [.leftMouseUp])
        
        info(app.localizedName! + " ✅")
        let name = self.app.localizedName ?? "unkown app"
        deinitCallback.append {
            info("\(name) ❌")
        }
        
        let registryCallback = { [weak self] (notification: String, callback: @escaping Fn) in
            guard let window = self else { return }
            let pid = window.app.processIdentifier
            let escapeFn = EscapeFn {
                callback()
            }
            let unregistry = Observer.addAX(notification: notification,
                                            pid: pid,
                                            axApp: AXUIElementCreateApplication(pid),
                                            fn: escapeFn)
            window.deinitCallback.append(unregistry)
        } // end: registryCallback
        registryCallback(kAXWindowMiniaturizedNotification) { [weak self] in
            guard let window = self else { return }
            windowManager.notifyWindowRemoved(window.cond)
        }
        registryCallback(kAXWindowDeminiaturizedNotification) { [weak self] in
            guard let window = self else { return }
            windowManager.notifyWindowCreated(window)
        }
        registryCallback(kAXUIElementDestroyedNotification) { [weak self] in
            guard let window = self else { return }
            if window.isAlive() {
                return
            }
            windowManager.notifyWindowRemoved(window.cond)
        }
        return btn
    }()
    // window status
    var spaceID: Int? = nil
    var spaceOrder: Int? = nil
    var WindowID: CGWindowID? = nil
    
    init(app: NSRunningApplication, axWindow: AXUIElement) {
        self.app = app
        self.axWindow = axWindow
        self.spaceID = -1
        self.spaceOrder = -1
        self.WindowID = AXWindow.getID(window: axWindow)
    }
    
    deinit {
        deinitCallback.forEach({ $0() })
    }
    
    @objc func switchWindow(_ sender: NSButton) {
        let activateWindow = {
            let window = sender.target as! Window
            //            AXUIElementSetAttributeValue(window.axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            //            AXUIElementSetAttributeValue(window.axWindow, kAXMainWindowAttribute as CFString, kCFBooleanTrue)
            if !window.app.activate() {
                print("activate failed.")
            }
        }
        if let event = NSApp.currentEvent {
            if event.modifierFlags.contains(.option) && event.modifierFlags.contains(.command) {
                activateWindow()
                windowManager.minimizeOtherWindowExcept(self.cond)
                return
            }
            if event.modifierFlags.contains(.option) {
                minimize()
                return
            }
            if event.modifierFlags.contains(.shift) {
                windowManager?.notifyWindowPinned(self.cond)
                return
            }
            activateWindow()
        }
    }
    
    func minimize() {
        if !AXWindow.minimize(window: self.axWindow) {
            notify(msg: "minimize failed! \(String(describing: self.app.localizedName))")
        }
    }
    
    func pin() {
        let pin = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil)!
        pin.size = NSSize(width: 9, height: 9)
        self.btn.image = iconAddSubscript(img: self.baseIcon, sub: pin)
    }
    
    func unpin() {
        self.btn.image = self.baseIcon
    }
    
    func updateSpace() {
        let currentSpaceID = AXWindow.getWindowSpaceID(window: axWindow)
        if self.spaceID == currentSpaceID { return }
        
        let currentSpaceOrder = AXWindow.getWindowSpaceOrder(window: axWindow)
        
        if self.spaceOrder == nil && currentSpaceOrder != nil {
            windowManager.notifyWindowExitFullscreen(self.cond)
        } // window exit fullscreen model
        
        if self.spaceOrder != nil && currentSpaceOrder == nil  {
            windowManager.notifyWindowEnterFullscreen(self.cond)
        } // window enter fullscreen model
        
        // update status
        self.spaceID = currentSpaceID
        self.spaceOrder = currentSpaceOrder
        
    }
    
    func isAlive() -> Bool {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        if getAXWindowFromAXApp(axApp: axApp) != nil {
            return true
        }
        return false
    }
    
    static func cond(window: Window, app: NSRunningApplication) -> Bool {
        return window.app == app
    }
    
    func cond(window: Window) -> Bool {
        return window == self
    }
    
    static func == (lhs: Window, rhs: Window) -> Bool {
        return lhs.app == rhs.app
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
