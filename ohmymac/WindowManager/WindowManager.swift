//
//  WindowMenuManager.swift
//  ohmymac
//
//  Created by huahua on 2024/3/31.
//

import Foundation
import AppKit
import Cocoa

var windowManager: WindowManager? = nil

func startWindowMenuManager() {
    windowManager = WindowManager()
}

class WindowManager {

    var applications: [Application] = []
    
    // status
    var lastActiveWindowWeakRef: WindowCond? = nil
    
    
    init() {
        let initApplicationFunc = { [self] (nsapp: NSRunningApplication) in
            if nsapp.localizedName == "ohmymac" { return }
            if nsapp.localizedName == "CursorUIViewService" { return }
            if nsapp.localizedName == "" { return }
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
        guard var axWindows = axApp.allWindows() else {
            throw ErrCode.RetryErr
        }
        if axWindows.count == 0 {
            if let window = axApp.mainWindow() { axWindows.append(window); return axWindows }
            if let window = axApp.focusedWindow() { axWindows.append(window); return axWindows }
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







