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
    
    if let panel = QLPreviewPanel.shared() {
        fm.getFocused()
        panel.dataSource = ql
        panel.delegate = ql
        panel.makeKeyAndOrderFront(fm)
    }
}

func qlMessage(msg: String) {
    openQuickLook(file: writeTmp(content: msg)!)
}


fileprivate class QuickLook: NSViewController, QLPreviewPanelDelegate, QLPreviewPanelDataSource {
    
    var url: URL?
    var sharedPanel:QLPreviewPanel? = nil
    
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }
    
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        sharedPanel = panel
        
    }
    
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        sharedPanel = nil
    }
    
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
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.miniaturizable, .closable, .resizable, .titled],
            backing: .buffered, defer: false)
        window.title = "QuickLook Window"
        window.backgroundColor = NSColor.clear
        window.alphaValue = 0.0
        return window
    }())
    
    fm.addCallback {
        if !lock.unlock() { debugPrint("ql unlock failed!"); return }
        if let panel = QLPreviewPanel.shared() {
            panel.close()
        }
    }
    
    Observer.addGlobally(notice: NSWorkspace.didDeactivateApplicationNotification) { notice in
        guard let nsapp = notice.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
        if nsapp.localizedName == "ohmymac" {
            fm.recoverFocused()
        }
    }
    
    Observer.addLocally(notice: NSWindow.willCloseNotification) { notice in
        if notice.object is NSWindow,
           notice.object as? NSWindow == QLPreviewPanel.shared() {
            fm.recoverFocused()
        }
    }

    return fm
}()
