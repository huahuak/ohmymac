//
//  RencentWindow.swift
//  ohmymac
//
//  Created by huahua on 2024/3/10.
//

import Foundation
import AppKit

var rwm: RecentWindowManager?

func startRecentWindowManger() {
    rwm = RecentWindowManager()
}

class RecentWindowManager {
    var observer: AXObserver?
    var wsas: [WindowSwitchAction] = []
    var iHide: [WindowSwitchAction] = []
    var rwsas: [WindowSwitchAction] = []
    let wss: WindowSwitchShortcut = {
        var wss = WindowSwitchShortcut()
        WindowSwitchShortcut.startCGEvent(wss: &wss)
        return wss
    }()
    var unhideOB: Any? = nil
    
    init() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        let activeOB = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: nil) { [self] notification in
                addWSA(notification: notification)
        }
        let launchOB = notificationCenter.addObserver(
            forName: NSWorkspace.willLaunchApplicationNotification, object: nil, queue: nil) { [self] notification in
                Thread.sleep(forTimeInterval: 1)
                addWSA(notification: notification)
        }
        unhideOB = notificationCenter.addObserver(
            forName: NSWorkspace.didUnhideApplicationNotification, object: nil, queue: nil) { [self] notification in
                addWSA(notification: notification)
        }
        notificationCenter.addObserver(self, selector:
                                        #selector(removeWSA(notification:)),
                                       name: NSWorkspace.didHideApplicationNotification, 
                                       object: nil)
        NSWorkspace.shared.runningApplications.forEach({ app in
            if app.isHidden { return }
            global.async {
                let axApp = AXUIElementCreateApplication(app.processIdentifier)
                if let axWin = WindowAction.getSingleWindowElement(axApp) {
                    main.async { [self] in
                        append(activatedApp: app, frontMostWindow: axWin)
                    }
                }
            }
        })
        deInitFunc.append { [self] in
            notificationCenter.removeObserver(self)
            notificationCenter.removeObserver(launchOB)
            notificationCenter.removeObserver(activeOB)
            if let unhideOB = unhideOB { notificationCenter.removeObserver(unhideOB) }
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
        if activatedApp.localizedName == "ohmymac" { return }
        internalShow()
        removeAll(cond: { wsa in
            return WindowAction.getSingleWindowElement(
                AXUIElementCreateApplication(wsa.app.processIdentifier)) == nil
        })
        append(activatedApp: activatedApp, frontMostWindow: frontMostWindow)
    }
    
    @objc func removeWSA(notification: Notification) {
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        removeAll(cond: {wsa in wsa.app == activatedApp})
    }
    
    func internalHide(show: WindowSwitchAction) {
        if iHide.count > 0 {
            qlMessage(msg: "BUG: iHide locked")
            return
        }
        let cond = { (wsa: WindowSwitchAction) in
            return wsa != show
        }
        wsas.forEach({ wsa in
            if !cond(wsa) { return }
            let img = wsa.btn.image
            wsa.btn.image = img?.convertToGrayScale()
            iHide.append(wsa)
        })
        wsas.removeAll(where: cond)
        iHide.forEach({ wsa in wsa.app.hide() })
    }
    
    func internalShow() {
        if iHide.isEmpty { return }
        let disableUnhideNotification = { [self] (f: Fn) in
            NSWorkspace.shared.notificationCenter.removeObserver(unhideOB!)
            f()
            main.async {
                self.unhideOB = NSWorkspace.shared.notificationCenter
                    .addObserver(
                        forName: NSWorkspace.didUnhideApplicationNotification,
                        object: nil, queue: nil, using: self.addWSA)
            }
        }
        disableUnhideNotification {
            iHide.reversed().forEach({ wsa in
                if let icon = wsa.app.icon {
                    wsa.btn.image = icon
                }
                wsas.insert(wsa, at: 0)
                wsa.app.unhide()
            })
            iHide.removeAll()
        }
    }
    
    func removeAll(cond: (WindowSwitchAction) -> Bool) {
        var toRemove: [WindowSwitchAction] = []
        wsas.forEach({ wsa in
            if cond(wsa) {
                toRemove.append(wsa)
            }
        })
        
        toRemove.forEach({ rm in menu.clean(rm.btn); rwsas.append(rm)})
        wsas.removeAll(where: cond)
    }
    
    func append(activatedApp: NSRunningApplication, frontMostWindow: AXUIElement) {
        // swap
        let cond = { (wsa: WindowSwitchAction) in
            wsa.app == activatedApp
        }
        if let wsa = wsas.first(where: cond) {
            wsas.removeAll(where: cond)
            wsas.append(wsa)
            wsa.winEle = frontMostWindow
            menu.show(wsa.btn)
            return
        }
        // cache
        if let wsa = rwsas.first(where: cond) {
            rwsas.removeAll(where: cond)
            wsas.append(wsa)
            menu.show(wsa.btn)
            return
        }
        
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

class WindowSwitchAction: Equatable {
    let btn: NSButton
    var winEle: AXUIElement
    let app: NSRunningApplication
    
    init(_ img: NSImage, windowElement: AXUIElement, application: NSRunningApplication) {
        btn = createMenuButton(img)
        winEle = windowElement
        app = application
        btn.target = self
        btn.action = #selector(switchWindow(_:))
        btn.sendAction(on: [.leftMouseUp])
        print(app.localizedName! + " is created.")
    }
    
    deinit {
        print((app.localizedName ?? "unkown app") + " is removed")
        menu.clean(btn) // BUG
    }
    
    @objc func handleThreeFingerSwipe(_ gestureRecognizer: NSGestureRecognizer) {
            if gestureRecognizer.state == .ended {
                print("Three-finger swipe detected!")
            }
        }
    
    @objc func switchWindow(_ sender: NSButton) {
        let sw = {
            let wsa = sender.target as! WindowSwitchAction
            wsa.app.activate()
            let windowElement = wsa.winEle
            AXUIElementSetAttributeValue(windowElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(windowElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        }
        let hideOtherOnlyOnce = { [rwm] in
            main.async { rwm?.internalHide(show: self) }
        }
        if let event = NSApp.currentEvent {
            sw()
            if event.modifierFlags.contains(.option) {
                hideOtherOnlyOnce()
            }
        }

        return
    }
    
    static func == (lhs: WindowSwitchAction, rhs: WindowSwitchAction) -> Bool {
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
                main.async {
                    notify(msg: "cmd+tab shortcut was disabled by timeout!\nnow restart...")
                }
                if let eventTap = wss.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
            }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if !wss.doing && keyCode == 48 && event.flags.contains(.maskCommand) { // cmd + tab
                wss.doing = true
                main.async { wss.start() }
                return nil
            }
            if wss.doing && keyCode == 48 && event.flags.contains(.maskCommand) {
                wss.cnt += 1
                main.async { wss.next(wss.cnt) }
                return nil
            }
            if wss.doing && !event.flags.contains(.maskCommand) {
                wss.doing = false
                main.async { wss.end(wss.cnt) }
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
        
        wss.eventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
}


extension NSImage {
    func convertToGrayScale() -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIColorControls")!
        filter.setDefaults()
        filter.setValue(ciImage, forKey: "inputImage")
        filter.setValue(0.0, forKey: "inputSaturation")

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let rep = NSCIImageRep(ciImage: outputImage)
        let nsImage = NSImage(size: self.size)
        nsImage.addRepresentation(rep)

        return nsImage
    }
}
