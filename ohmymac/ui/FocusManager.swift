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

class FocusManager: NSWindowController, NSWindowDelegate {
    private var defocused: Fn?
    var callback: Fn? // callback when window closed.
    
    init(window: NSWindow) {
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func windowWillClose(_ notification: Notification) {
        defocused?()
        callback?()
    }
    
    func getFocused() {
        let app = NSWorkspace.shared.frontmostApplication
        self.defocused = { [weak self] in
            app?.activate()
            self?.defocused = nil
        }

        self.window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// `recoverFocused` will close window,
    /// and `windowWillClose` will be executed.
    func recoverFocused() {
        window?.close()
    }
    
    func addCallback(fn: @escaping Fn) {
        if let callback = self.callback {
            self.callback = {
                callback()
                fn()
            }
            return
        }
        self.callback = fn
    }
}
