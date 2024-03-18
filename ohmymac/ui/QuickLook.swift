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

fileprivate let ql = QuickLook()
fileprivate let lock = Lock(before: menu.busy, after: menu.free)

func openQuickLook(file: URL) {
    if !lock.lock() { debugPrint("QuickLook is locked."); return }
    ql.url = file
    
    if let panel = QLPreviewPanel.shared(), 
        fm.getFocused() {
            panel.dataSource = ql
            panel.makeKeyAndOrderFront(nil)
    }
}

func qlMessage(msg: String) {
    openQuickLook(file: writeTmp(content: msg)!)
}


fileprivate class QuickLook: QLPreviewPanelDataSource {
    
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
        if notice.object is NSWindow,
           notice.object as? NSWindow == QLPreviewPanel.shared() {
            fm.recoverFocused()
            if !lock.unlock() { debugPrint("ql unlock failed!"); return }
        }
    }
    
    return fm
}()
