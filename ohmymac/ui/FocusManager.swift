//
//  FocuseManager.swift
//  huahuamac
//
//  Created by huahua on 2023/8/28.
//

import Foundation
import Cocoa
import QuickLookUI

// COMMENT:
// FocusManager which is used by ui, is used to let window get focused thought other app is in fullscreen,
//    then activate original window when ui window is closed.

class FocusManager {
    var window: NSWindow
    var callback: Fn?
    
    init(window: NSWindow) {
        self.window = window
    }
    
    func getFocused() -> Bool {
        let app = NSWorkspace.shared.frontmostApplication
        self.callback = {
            app?.activate()
            self.callback = nil
        }

        NSWindowController(window: window).showWindow(nil)
        let ok = NSRunningApplication.current.activate(options: [.activateAllWindows])
        if !ok {
            debugPrint("get focused failed")
            callback?()
            return false
        }
        return true
    }

    func recoverFocused() {
        callback?()
        window.close()
    }
    
    func addObserver(name: NSNotification.Name?, using: @escaping (Notification) -> Void) {
        let observer = NotificationCenter.default
            .addObserver(forName: name, object: nil, queue: nil, using: using)
        deInitFunc.append {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
