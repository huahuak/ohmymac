//
//  Application.swift
//  ohmymac
//
//  Created by huahua on 2024/4/5.
//

import Foundation
import AppKit

typealias ApplicationCond = (Application) -> Bool

class Application {
    let nsApp: NSRunningApplication
    let axApp: AXUIElement
    // different status window
    private var windows: [Window] = []
    private var lastWindow: Window?
    var deinitCallback: [Fn] = []
    
    init(app: NSRunningApplication) {
        self.nsApp = app
        self.axApp = AXUIElementCreateApplication(nsApp.processIdentifier)
        registerObserver()
        info("\(name()) ✅")
    }
    
    deinit {
        deinitCallback.forEach{$0()}
        info("\(name()) ❌")
    }
    
    func registerObserver() {
        func registerHelper(_ notifications: String..., doing: @escaping (Application, AXUIElement) -> Void) {
            let escapeFn = EscapeObserverExecutor { [weak self] axui in
                guard let app = self else { warn("Application.registerObserver(): app has been removed!"); return }
                doing(app, axui)
            }
            let unregistry = Observer.add(notifications: notifications,
                                          pid: nsApp.processIdentifier,
                                          axui: axApp,
                                          fn: escapeFn)
            deinitCallback.append(unregistry)
        }
        
        registerHelper(kAXWindowCreatedNotification) { app, axui in
            guard let window = Window(app: app, axWindow: axui) else { return }
            app.appendWindow(window)
        }
        registerHelper(kAXMainWindowChangedNotification) {app, axui in
            app.notifyActivate(axWindow: axui)
        }
    }
    
    /// appendWindow will add window to application only when it is not exist.
    /// then refresh application icon in menubar.
    /// finally, notify WindowManager something happen.
    func appendWindow(_ window: Window) {
        if windows.contains(where: window.cond) {
            warn("Application.appendWindow(): window exist!")
            return
        }
        windows.append(window)
        if let last = lastWindow {
            menu.clean(last.btn)
        }
        lastWindow = window
        menu.show(window.btn)
        // notify WindowManager
        WindowManager.notifyWindowActivated(window.cond)
    }
    
    /// remove all window ref in the application, then remove from menubar automatically.
    private func removeWindow(_ cond: WindowCond) {
        guard let window = windows.first(where: cond) else {
            warn("Application.removeWindow(): window not found!")
            return
        }
        
        windows.removeAll(where: cond)
        if window == lastWindow {
            lastWindow = nil
        }
        menu.clean(window.btn)
    }
    
    /// remove last window btn, then add new window into menubar
    func notifyWindowActivated(_ cond: WindowCond) throws {
        guard let window = findWindow(cond) else { throw ErrCode() }
        removeWindow(window.cond)
        appendWindow(window)
    }
    
    // MARK: window notification
    /// first remove window,
    /// then add the most recent window to menubar.
    func notifyWindowClosed(_ cond: WindowCond) {
        removeWindow(cond)
        
        if let last = windows.last {
            lastWindow = last
            menu.show(last.btn)
        }
    }
    
    func notifyWindowMinimized(_ cond: WindowCond) {
        guard let window = findWindow(cond) else { return }
        removeWindow(cond)
        windows.insert(window, at: 0) // move to minimized window head.
        
        if let last = windows.last {
            lastWindow = last
            menu.show(last.btn)
        }
    }
    
    
    // MARK: application notification
    /// remove window in menubar.
    func notifyHidden() {
        if let last = lastWindow {
            menu.clean(last.btn)
        }
    }
    
    func notifyShown() {
        if let last = lastWindow {
            menu.show(last.btn)
        }
    }
    
    /// notifyActivate is called when app activate
    /// then choose last active window to show
    func notifyActivate(axWindow: AXUIElement?) {
        // axWindow is main window which is changed
        if let axw = axWindow {
            if let window = windows.filter({ $0.axWindow.windowID() == axw.windowID() }).first {
                removeWindow(window.cond)
                appendWindow(window)
            } else {
                // window not found, need to append
                guard let window = Window(app: self, axWindow: axw) else { return }
                appendWindow(window)
            }
        } else if let last = lastWindow { // axWindow is nil, just try refresh
            removeWindow(last.cond)
            appendWindow(last)
        }
    }

}

extension Application {
    func eq(_ nsapp: NSRunningApplication) -> Bool {
        self.nsApp.processIdentifier == nsapp.processIdentifier
    }
    
    func cond(_ app: Application) -> Bool {
        self.eq(app.nsApp)
    }
    
    func name() -> String {
        return nsApp.localizedName ?? "Unknown App"
    }
    
    func findWindow(_ cond: WindowCond) -> Window? {
        windows.first(where: cond)
    }
    

}
