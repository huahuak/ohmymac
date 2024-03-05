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
    var window: NSWindow!

    var callback: (() -> Void)?
    
    init(window: NSWindow) {
        self.window = window
    }
    
    func getFocused(WhenFinished: (() -> Void)?) -> Bool {
    
        let app = NSWorkspace.shared.frontmostApplication
        self.callback = {
            if let fi = WhenFinished { fi() }
            if let app = app { app.activate() }
            self.callback = nil
        }
        
        guard let window = window else { debugPrint("window is nil"); return false}
        NSWindowController(window: window).showWindow(nil)
        let ok = NSRunningApplication.current.activate(options: [.activateAllWindows])
        
        if !ok {
            debugPrint("get focused failed")
            if let cl = callback { cl() }
            return false
        }
        
        return true
    }

    func addObserver(name: NSNotification.Name?, using: @escaping (Notification) -> Void) {
        let observer = NotificationCenter.default
            .addObserver(forName: name, object: nil, queue: nil, using: using)
        deInitFunc.append {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
