//
//  Window.swift
//  ohmymac
//
//  Created by huahua on 2024/4/5.
//

import Foundation
import AppKit

typealias WindowCond = (Window) -> Bool

enum WindowStatus: Int {
    case none = -1
    case onSpace = 1
    case minimize = 2
    case fullscreen = 3
}

class Window: Equatable {
    weak var app: Application? // hold parent application
    var axWindow: AXUIElement
    let nsApp: NSRunningApplication
    let windowID: CGWindowID
    var status: WindowStatus = .none
    var isPinned: Bool
    var deinitCallback: [Fn] = []
    
    init?(app: Application, axWindow: AXUIElement) {
        self.app = app
        self.nsApp = app.nsApp
        self.axWindow = axWindow
        guard let windowID = axWindow.windowID(),
              let level = axWindow.windowLevel(),
              level == CGWindowLevelForKey(.normalWindow),
              axWindow.windowSize() != nil,
              axWindow.windowTitle() != nil,
              [kAXStandardWindowSubrole, kAXDialogSubrole].contains(axWindow.subrole())
        else {
            info("\(nsApp.localizedName ?? "unkown app") want to create no allowed window!")
            return nil
        }
        self.windowID = windowID
        self.isPinned = false
        registerObserver()
        info("application {\(nsApp.localizedName!)} append window is {\(axWindow.windowTitle()!)}")
        main.async { self.updateStatus() } // delay update status
    }
    
    deinit {
        deinitCallback.forEach{ $0() }
    }
    
    func registerObserver() {
        func registerHelper(_ notifications: String..., doing: @escaping (Application, Window) -> Void) {
            let escapeFn = EscapeObserverExecutor { [weak self] axui in
                guard let window = self else { warn("Window.registerObserver(): window has been removed!"); return }
                guard let app = window.app else { warn("Window.registerObserver(): app has been removed!"); return }
                if axui.windowID() == nil {
                    app.removeWindow(window.cond)
                    window.removeFromMenu()
                    return
                }
                doing(app, window)
            }
            let unregistry = Observer.add(notifications: notifications,
                                          pid: nsApp.processIdentifier,
                                          axui: axWindow,
                                          fn: escapeFn)
            deinitCallback.append(unregistry)
        }
        registerHelper(kAXUIElementDestroyedNotification,
                       kAXWindowMiniaturizedNotification,
                       kAXWindowDeminiaturizedNotification) { app, window in
            window.updateStatus()
        }
    }
    
    func updateStatus() {
        let old = status
        status = Window.getStatus(axWindow: axWindow)
        if old == status {
            return
        }
        switch status {
        case .none:
            return
        case .onSpace:
            if old == .fullscreen {
                pin()
            }
            addToMenu()
        case .fullscreen:
            if old == .onSpace {
                unpin()
            }
            addToMenu()
        case .minimize:
            removeFromMenu()
        }
    }
    
    func addToMenu() {
        do {
            try app?.showWindow(cond)
        } catch {
            warn("delay update failed!")
            menu.show(btn)
        }
    }
    
    func removeFromMenu() {
        unpin()
        do {
            try app?.unshowWindow(cond)
        } catch {
            warn("delay update failed!")
            menu.clean(btn)
        }
    }
    
    func minimize() {
        axWindow.minimize()
    }
    
    // ------------------------------------ //
    // for button
    // ----------------------------------- //
    func pin() {
        self.isPinned = true
        self.btn.image = iconAddSubscript(img: self.baseIcon, sub: type(of: self).pinIcon)
    }
    
    func unpin() {
        self.isPinned = false
        self.btn.image = self.baseIcon
    }
    
    lazy var baseIcon = {
        let img = nsApp.icon
        img?.size = NSSize(width: 22, height: 22)
        return img ?? randomIcon()
    }()
    static let pinIcon = {
        let pin = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil)!
        pin.size = NSSize(width: 9, height: 9)
        return pin
    }()
    lazy var btn: NSButton = {
        let btn = createMenuButton(self.baseIcon)
        btn.target = self
        btn.action = #selector(clickAction(_:))
        btn.sendAction(on: [.leftMouseUp])
        deinitCallback.append {
            menu.clean(btn)
        }
        return btn
    }()
    
    @objc func clickAction(_ sender: NSButton) {
        let activateWindow = {
            let window = sender.target as! Window
            if !window.nsApp.activate() {
                print("activate failed.")
            }
        }
        if let event = NSApp.currentEvent {
            if event.modifierFlags.contains(.option) && event.modifierFlags.contains(.command) {
                activateWindow()
//                windowManager.minimizeOtherWindowExcept(self.cond)
                return
            }
            if event.modifierFlags.contains(.option) {
//                minimize()
                return
            }
            if event.modifierFlags.contains(.shift) {
                pin()
                return
            }
            activateWindow()
        }
    }
    
    static func == (lhs: Window, rhs: Window) -> Bool {
        return lhs.windowID == rhs.windowID
    }
}

extension Window {
    func cond(window: Window) -> Bool {
        return window == self
    }
    
    static func getStatus(axWindow: AXUIElement) -> WindowStatus {
        if axWindow.isMinimized() ?? false { return WindowStatus.minimize }
        if axWindow.isFullScreent() ?? false { return WindowStatus.fullscreen }
        return WindowStatus.onSpace
    }
}
