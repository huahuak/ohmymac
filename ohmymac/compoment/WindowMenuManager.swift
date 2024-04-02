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

fileprivate var windowMenuManager: WindowMenuManager? = nil
fileprivate var keepingWindow: WindowManager!  = nil
fileprivate var openingWindow: WindowManager!  = nil

func startWindowMenuManager() { // IMPORTANT: don't change init order!!!
    openingWindow = WindowManager()
    keepingWindow = WindowManager()
    windowMenuManager = WindowMenuManager()
}


// ------------------------------------ //
// window function
// ----------------------------------- //
fileprivate func getAXWindowFromAXApp(app: AXUIElement) -> AXUIElement? {
//    if let axWindow = AXWindow.getFocusedWindow(app: app) { return axWindow }
    if let axWindow = AXWindow.getMainWindow(app: app) { return axWindow }
    return nil
}

fileprivate func getWindowFromFrontMostApp() -> Window? {
    if let app = NSWorkspace.shared.frontmostApplication,
       let axWindow = getAXWindowFromAXApp(app: AXUIElementCreateApplication(app.processIdentifier)) {
        return Window(app: app, axWindow: axWindow)
    }
    return nil
}

let pinWindowHandler = {
    if let window = getWindowFromFrontMostApp() {
        markKeepWindow(window: window)
    }
} // for shortcut

// ------------------------------------ //
// remove 
// ----------------------------------- //
fileprivate typealias WindowFn = (Window) -> Bool
fileprivate var removeHandler: [WindowFn] = []
fileprivate var removeWindow = { (window: Window) in removeHandler.forEach({ _ = $0(window) })}
// ------------------------------------ //
// check
// ----------------------------------- //
fileprivate var checkHandler: [Fn] = []
fileprivate var check = { checkHandler.forEach({ $0() }) }
// ------------------------------------ //
// append
// ----------------------------------- //
fileprivate var appendWindow = { (window: Window) in
    if keepingWindow.windows.contains(where: {$0 == window}) {
        keepingWindow.append(window)
        window.pinIcon()
        return
    }
    openingWindow.append(window)
} 
fileprivate func markKeepWindow(window: Window) {
    if AXWindow.getWindowSpaceOrder(window: window.axWindow) == nil {
        return // don't mark fullscreent app.
    }
    openingWindow.remove(window)
    keepingWindow.append(window)
    window.pinIcon()
}
// ------------------------------------ //
// get
// ----------------------------------- //
fileprivate var getWindows: [() -> [Window]] = []
fileprivate var allWindows = {
    var windows: [Window] = []
    getWindows.forEach({ windows.append(contentsOf: $0()) })
    return windows
}

typealias notificationHandlerFunc = (Notification) -> Void

class handlerFuncBuilder {
    private var f: notificationHandlerFunc = { _ in }
    
    func append(name: NSNotification.Name, handler: @escaping notificationHandlerFunc) -> handlerFuncBuilder {
        let origin = f
        f = {
            origin($0)
            if $0.name == name {
                handler($0)
            }
        }
        return self
    }
    
    func build() -> notificationHandlerFunc { return f }
    
    func commingWindow(handler: @escaping notificationHandlerFunc)-> handlerFuncBuilder {
        didLaunchApplicationNotification(handler: handler)
            .didActivateApplicationNotification(handler: handler)
            .didUnhideApplicationNotification(handler: handler)
    }
    
    func didLaunchApplicationNotification(handler: @escaping notificationHandlerFunc) -> handlerFuncBuilder {
        append(name: NSWorkspace.didLaunchApplicationNotification, handler: handler)
    }
    
    func didActivateApplicationNotification(handler: @escaping notificationHandlerFunc) -> handlerFuncBuilder {
        append(name: NSWorkspace.didActivateApplicationNotification, handler: handler)
    }
    
    func didHideApplicationNotification(handler: @escaping notificationHandlerFunc) -> handlerFuncBuilder {
        append(name: NSWorkspace.didHideApplicationNotification, handler: handler)
    }
    
    func didUnhideApplicationNotification(handler: @escaping notificationHandlerFunc) -> handlerFuncBuilder {
        append(name: NSWorkspace.didUnhideApplicationNotification, handler: handler)
    }
    
    func activeSpaceDidChangeNotification(handler: @escaping notificationHandlerFunc) -> handlerFuncBuilder {
        append(name: NSWorkspace.activeSpaceDidChangeNotification, handler: handler)
    }
}

fileprivate class WindowMenuManager {
    let wss: WindowSwitchShortcut = {
        var wss = WindowSwitchShortcut()
        WindowSwitchShortcut.startCGEvent(wss: &wss)
        return wss
    }()
    
    // window event handler
    let openings = WindowManager()
    let pins = WindowManager()
    var actor: [notificationHandlerFunc] = []
    
    var shift = false
    
    static func handlerBuilder(origin: notificationHandlerFunc) {
        
    }
    
    init() {
        // init handler
        let openingHandler = handlerFuncBuilder()
            .commingWindow {
                WindowMenuManager.getWindowFromNotice($0) {
                    check()
                    self.openings.append($0)
                    $0.minimizeOtherWindow()
                }
            }
            .build()
        // init status
        NSWorkspace.shared.runningApplications.forEach({ app in
            if app.isHidden { return }
            let appendWindowFunc = {
                let axApp = AXUIElementCreateApplication(app.processIdentifier)
                if let axWindow = getAXWindowFromAXApp(app: axApp) {
                    let window = Window(app: app, axWindow: axWindow)
                    main.async { appendWindow(window) }
                }
            }
            global.async { appendWindowFunc() }
        })
        // add event
        let addEvent = { (event: @escaping @Sendable (Notification) -> Void, notice: Notification.Name...) in
            notice.forEach({
                let observer = NSWorkspace.shared.notificationCenter
                    .addObserver(forName: $0, object: nil, queue: nil) { notice in
                        main.async { event(notice) }
                    }
                deInitFunc.append({
                    NSWorkspace.shared.notificationCenter.removeObserver(observer)
                })
            })
        }
        let comingWindowHandler: @Sendable (Notification) -> Void = { notice in
            WindowMenuManager.getWindowFromNotice(notice) { window in
                check()
                if self.shift { // keep window singal
                    markKeepWindow(window: window)
                    openingWindow.currentSpaceWindow().forEach(markKeepWindow)
                    return
                }
                appendWindow(window)
                window.minimizeOtherWindow()

            }
        } // comingWindowHandler
        let removeWindowHandler: @Sendable (Notification) -> Void = { notice in
            WindowMenuManager.getWindowFromNotice(notice) {
                removeWindow($0)
            }
        } // removeWindowHandler
        let updateSpaceHandler: @Sendable (Notification) -> Void = { _ in
            WindowManager.currentSpaceWindow(windows: allWindows()).forEach({
                $0.updateSpace()
            })
        } // updateSpaceHandler
        addEvent(
            comingWindowHandler,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification
        )
        addEvent(
            removeWindowHandler,
            NSWorkspace.didHideApplicationNotification
        )
        addEvent(
            updateSpaceHandler,
            NSWorkspace.activeSpaceDidChangeNotification
        )
        // add monitor
        let addMonitor = { (flags: NSEvent.EventTypeMask, event: @escaping (NSEvent) -> Void) in
            if let monitor = NSEvent.addGlobalMonitorForEvents(matching: flags, handler: event) {
                deInitFunc.append {
                    NSEvent.removeMonitor(monitor)
                }
            }
        }
        addMonitor(.flagsChanged) { event in
            self.shift = event.modifierFlags.contains(.shift)
        }
    }
    
    static func getWindowFromNotice(_ notification: Notification,
                             handler: @escaping (Window) -> Void) {
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        if activatedApp.localizedName == "ohmymac" { return }
        if activatedApp.localizedName == "Finder" { return }
        // TOOD Finder bug with GetID
        let axApp = AXUIElementCreateApplication(activatedApp.processIdentifier)
        var axWindow = getAXWindowFromAXApp(app: axApp)
        if axWindow == nil {
            Thread.sleep(forTimeInterval: 0.2)
            axWindow = getAXWindowFromAXApp(app: axApp)
        }
        guard let exist = axWindow else { return }
        handler(Window(app: activatedApp, axWindow: exist))
    }
}

fileprivate class WindowManager {
    var windows: [Window] = []
    
    init() {
        removeHandler.append { self.remove($0); return true }
        checkHandler.append(check)
        getWindows.append { return self.windows }
    }
    
    func append(_ window: Window) {
        remove(window)
        windows.append(window)
        menu.show(window.btn)
    }
    
    func remove(_ window: Window) {
        windows.filter({ $0 == window }).forEach({ window in
            debugPrint("\(window.app.localizedName ?? "unkown app") ❌")
            menu.clean(window.btn)
        })
        windows.removeAll(where: { $0 == window })
    }
    
    func check() {
        let deadWindow = windows.filter({
            let axApp = AXUIElementCreateApplication($0.app.processIdentifier)
            return getAXWindowFromAXApp(app: axApp) == nil
        })
        deadWindow.forEach(remove)
    }
    
    static func currentSpaceWindow(windows: [Window]) -> [Window] {
        windows.filter({
            AXWindow.activatedSpaceID() == 
            AXWindow.getWindowSpaceID(window: $0.axWindow)
        })
    }
    
    func currentSpaceWindow() -> [Window] {
        return WindowManager.currentSpaceWindow(windows: windows)
    }
}

fileprivate class Window: Equatable {
    var axWindow: AXUIElement
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
    // window status
    var spaceID: Int? = nil
    var spaceOrder: Int? = nil
    var WindowID: CGWindowID? = nil
    
    init(app: NSRunningApplication, axWindow: AXUIElement) {
        self.app = app
        self.axWindow = axWindow
        self.spaceID = AXWindow.getWindowSpaceID(window: axWindow)
        self.spaceOrder = AXWindow.getWindowSpaceOrder(window: axWindow)
        self.WindowID = AXWindow.getID(window: axWindow)
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
                minimizeOtherWindow()
                return
            }
            if event.modifierFlags.contains(.option) {
                minimizeWindow()
                return
            }
            if event.modifierFlags.contains(.shift) {
                markKeepWindow(window: self)
                return
            }
            activateWindow()
        }
    }
    
    func minimizeWindow() {
        if !AXWindow.minimize(window: self.axWindow) {
            notify(msg: "minimize failed! \(String(describing: self.app.localizedName))")
        }
        removeWindow(self)
    }
    
    func minimizeOtherWindow() {
        openingWindow.currentSpaceWindow()
            .filter({ $0 != self })
            .forEach({ window in
                if !AXWindow.minimize(window: window.axWindow) {
                    notify(msg: "minimize failed! \(String(describing: window.app.localizedName))")
                }
                removeWindow(window)
            })
    }
    
    func updateSpace() {
        let currentSpaceID = AXWindow.getWindowSpaceID(window: axWindow)
        if self.spaceID == currentSpaceID { return }
        
        let currentSpaceOrder = AXWindow.getWindowSpaceOrder(window: axWindow)
        
        if self.spaceOrder == nil && currentSpaceOrder != nil {
            markKeepWindow(window: self)
        } // window exit fullscreen model
        
        if self.spaceOrder != nil && currentSpaceOrder == nil  {
            keepingWindow.remove(self)
            appendWindow(self)
            icon()
        } // window enter fullscreen model
        
        // update status
        self.spaceID = currentSpaceID
        self.spaceOrder = currentSpaceOrder
        
    }
    
    private func baseIcon() -> NSImage {
        let img = app.icon
        img?.size = NSSize(width: 22, height: 22)
        return img ?? randomIcon()
    }
    
    func icon() {
        self.btn.image = self.baseIcon()
    }
    
    func pinIcon() {
        let number = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil)!
        number.size = NSSize(width: 9, height: 9)
        self.btn.image = iconAddSubscript(img: self.baseIcon(), sub: number)
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
