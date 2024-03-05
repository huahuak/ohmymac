//
//  Shortcut.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/25.
//

import Cocoa
import Atomics
import HotKey

// COMMENT:
// Shorcut compoment is used to listen shortcut keydown, then call some function and ui to response.

func startShortcut() {
    _init()
    deInitFunc.append {
        hotkeys.removeAll()
    }
}

var hotkeys = [HotKey]()

var doing = ManagedAtomic<Int>(0)

fileprivate func _init() {
    // MARK: - window action
    add(HotKey(key: .l, modifiers: [.option]), { percentExec(0.6, 0.8) })
    add(HotKey(key: .semicolon, modifiers: [.option]), { percentExec(0.75) })
    add(HotKey(key: .quote, modifiers: [.option]), { percentExec(0.9) })
    add(HotKey(key: .m, modifiers: [.option]), { percentExec(1) })
    add(HotKey(key: .c, modifiers: [.option]), {
        guard let front = WindowAction.getFrontMostWindow() else {
            debugPrint("get front most window failed, can't center window "); return
        }
        WindowAction.center(front)
    })
    
    // MARK: - translate quicklook
    add(HotKey(key: .comma, modifiers: [.option]), {
        one { doneFn in
            let text = getScreenText()
            translate(source: text) { result in
                guard let url = writeTmp(content: result) else { return }
                openQuickLook(file: url) { doneFn() }
            }
            
        }
    })
    
    // MARK: - google webview
    add(HotKey(key: .g, modifiers: [.option, .command]), {
        one { doneFn in
            let text = getScreenText()
            guard let url = googleSearchURL(content: text) else { return }
            openWebView(url: url) { doneFn() }
        }
    })
    
    // MARK: - internal function
    func add(_ hotkey: HotKey, _ handler: @escaping () -> ()) {
        hotkey.keyDownHandler = handler
        hotkeys.append(hotkey)
    }
    
    func one(f: @escaping (@escaping () -> Void) -> Void) {
        let (ok, old) = doing.compareExchange(expected: 0, desired: 1, ordering: AtomicUpdateOrdering.relaxed)
        if !ok {
            debugPrint("doing...")
            return
        }
        main.async {
            var oldImage: NSImage?
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate, let btn = appDelegate.menu.button  {
                oldImage = btn.image
                btn.image = NSImage(systemSymbolName: "rays", accessibilityDescription: nil)
            }
            f() {
                if let oldImage = oldImage {
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate, let btn = appDelegate.menu.button  {
                        btn.image = oldImage
                    }
                }
                doing.store(old, ordering: AtomicStoreOrdering.relaxed)
                debugPrint("one done!")
            }
        }
    }
    
    func percentExec(_ width: Double, _ height: Double = 1) {
        guard let frontMostWindow = WindowAction.getFrontMostWindow() else {
            debugPrint("get front most window failed"); return
        }
        WindowAction.percent(frontMostWindow, widthPercent: width, heightPercent: height)
    }
    
}

