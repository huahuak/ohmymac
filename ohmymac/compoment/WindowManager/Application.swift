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
    // different status wind
    private var windows: [Window] = []
    private var shown: [Window] = []
    var UIUpdateFn: [Fn] = []
    var deinitCallback: [Fn] = []
    
    init(app: NSRunningApplication) {
        self.nsApp = app
        self.axApp = AXUIElementCreateApplication(nsApp.processIdentifier)
        registerObserver()
        info("\(nsApp.localizedName ?? "unkown app") ✅")
    }
    
    deinit {
        deinitCallback.forEach{$0()}
        info("\(nsApp.localizedName ?? "unkown app") ❌")
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
        registerHelper(kAXFocusedWindowChangedNotification,
                       kAXMainWindowChangedNotification) {app, axui in
            app.notifyActivate()
        }
    }
    
    func appendWindow(_ window: Window) {
        if windows.contains(where: window.cond) {
            warn("Application.appendWindow(): window exist!")
            return
        }
        windows.append(window)
    }
    
    func removeWindow(_ cond: WindowCond) {
        guard let _ = windows.first(where: cond) else {
            warn("Application.removeWindow(): window not found!")
            return
        }
        windows.removeAll(where: cond)
    }
    
    func findWindow(_ cond: WindowCond) -> Window? {
        windows.first(where: cond)
    }
    
    func notifyHidden() {
        windows.forEach{ $0.removeFromMenu() }
    }
    
    func notifyShown() {
        windows.forEach{ $0.updateStatus() }
    }
    
    func notifyActivate() {
        let windowsOnCurrentSpace = windows
            .filter{ $0.axWindow.spaceID4Window() == AXUIElement.spaceID() }
        if windowsOnCurrentSpace.count == 1 {
            windowsOnCurrentSpace.first?.addToMenu()
            return
        }
        windowsOnCurrentSpace
            .first{ $0.axWindow.isFocusedWindow() ?? false }?
            .addToMenu()
    }
    
    func minimizeUnpinWindow() {
        windows
            .filter{ !$0.isPinned }
            .filter{ $0.axWindow.spaceID4Window() == AXUIElement.spaceID() }
            .forEach{ $0.minimize() }
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
    
    func showWindow(_ cond: WindowCond) throws {
        guard let window = findWindow(cond) else { throw ErrCode() }
        shown.removeAll(where: window.cond)
        shown.append(window)
        shown.forEach{ menu.clean($0.btn) }
        menu.show(window.btn)
    }
    
    func unshowWindow(_ cond: WindowCond) throws {
        guard let window = findWindow(cond) else { throw ErrCode() }
        shown.removeAll(where: window.cond)
        menu.clean(window.btn)
        if let show = shown.last {
            menu.show(show.btn)
        }
    }
}
