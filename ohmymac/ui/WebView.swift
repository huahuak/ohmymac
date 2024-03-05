//
//  Webview.swift
//  huahuamac
//
//  Created by huahua on 2023/8/28.
//

import Foundation
import Cocoa
import WebKit
import QuickLookUI
import SafariServices
import Atomics

// COMMENT:
// webview ui is used to show some url in webview.

func openWebView(url: URL, callback: (() -> Void)?) {
    wvControler.open(url)
    _ = fm.getFocused(WhenFinished: callback)
}

class WebViewController: NSViewController {
    
    var wv: IWebView?
    var isRunning = ManagedAtomic<Int>(0)
    
    func open(_ url: URL) {
        isRunning.store(1, ordering: .relaxed)
        let wv: IWebView = {
            if self.wv != nil { return self.wv!}
            
            self.wv = IWebView().inital()
            
            let checkTimeInterval = 60.0
            func check() {
                // debugPrint("check")
                let (ok, _) = isRunning.compareExchange(expected: 0, desired: 0, ordering: .relaxed)
                if !ok {
                    main.asyncAfter(deadline: .now() + checkTimeInterval, execute: check); return
                }
                if let wv = self.wv {
                    wv.removeFromSuperview()
                    self.wv = nil
                    // debugPrint("wv timeout")
                }
            }
            main.asyncAfter(deadline: .now() + checkTimeInterval, execute: check)
            return self.wv!
        }()
        
        
        let request = URLRequest(url: url)
        wv.load(request)
        
        
        view.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: view.topAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    func close() {
        guard let wv = wv else { return }
        
        wv.stopLoading()
        let emptyHTML = ""
        wv.loadHTMLString(emptyHTML, baseURL: nil)
        
        isRunning.store(0, ordering: .relaxed)
    }
}

class IWebView: WKWebView, WKNavigationDelegate {
    
    func inital() -> Self {
        navigationDelegate = self
        translatesAutoresizingMaskIntoConstraints = false
        allowsBackForwardNavigationGestures = true
        return self
    }
    
    func webView(_: WKWebView, decidePolicyFor: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) -> () {
        if decidePolicyFor.targetFrame == nil {
            load(decidePolicyFor.request)
        }
        decisionHandler(.allow)
    }
    
    deinit {
        debugPrint("wv deinit")
    }
}

fileprivate let wvControler = WebViewController()

fileprivate class WebViewWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.styleMask.insert(.fullSizeContentView)
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        self.isMovableByWindowBackground = true
        
    }
}

fileprivate let fm = {
    
    let window = WebViewWindow(contentViewController: wvControler)
    
    if let screen = NSScreen.screens.first?.frame {
        let widthPercent = 0.75
        let heightPercent = 0.85
        let x = screen.size.width * (1 - widthPercent) / 2.0
        let y = screen.size.height * (1 - heightPercent) * 0.66
        let width = round(screen.size.width * widthPercent)
        let height = round(screen.size.height * heightPercent)
        //        debugPrint("screen is \(screen.size.width) * \(screen.size.height)")
        //        debugPrint("x: \(x), y: \(y), w: \(width), h: \(height)")
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false, animate: true)
    }
    
    window.title = "Google Search"
    
    let fm = FocusManager(window: window)
    
    fm.addObserver(name: NSWindow.willCloseNotification) { notice in
        if notice.object is NSWindow, notice.object as? NSWindow == window {
            if let cl = fm.callback { cl() }
            wvControler.close()
        }
    }
    
    let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        if event.modifierFlags.contains(.command) && event.characters == "w" {
            let (ok, _) = wvControler.isRunning.compareExchange(expected: 1, desired: 1, ordering: .relaxed)
            if !ok {
                return event
            }
            debugPrint("web view space monitor")
            window.close()
            return nil
        }
        return event
    }
    
    deInitFunc.append {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }
    
    return fm
}()
