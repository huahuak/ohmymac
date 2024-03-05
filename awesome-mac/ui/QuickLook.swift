//
//  Quicklook.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/25.
//

import Cocoa
import QuickLookUI


// COMMENT:
// quicklook ui is used to show something in a quicklook pannel.

var ql = QuickLook()

func openQuickLook(file: URL, callback: (() -> Void)? = nil) {
    ql.url = file
    
    if let panel = QLPreviewPanel.shared(), 
        fm.getFocused(WhenFinished: callback) {
            panel.dataSource = ql
            panel.makeKeyAndOrderFront(nil)
    }
}


class QuickLook: QLPreviewPanelDataSource {
    
    var url: URL?
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return 1
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return url! as QLPreviewItem
    }
}

fileprivate let fm = {
    let fm = FocusManager(window: {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
            styleMask: [.miniaturizable, .closable, .resizable, .titled],
            backing: .buffered, defer: false)
        window.title = "QuickLook Window"
        window.backgroundColor = NSColor.clear
        window.alphaValue = 0.0
        return window
    }())
    
    fm.addObserver(name: NSWindow.willCloseNotification) { notice in
        if notice.object is NSWindow, notice.object as? NSWindow == QLPreviewPanel.shared() {
            if let cl = fm.callback { cl() }
            if let w = fm.window { w.close() }
        }
    }
    
    return fm
}()
