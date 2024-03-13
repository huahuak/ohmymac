//
//  WindowAction.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/24.
//

import Cocoa
import Atomics

// COMMENT:
// WindowAction Compoment is used to let window center automatically when created if stage manager enabled.

func startWindowAction() {
    let exec = WindowAction()
    exec.start()
    func addObserver(_ name: NSNotification.Name, _ select: Selector) {
        NSWorkspace.shared.notificationCenter.addObserver(exec, selector: select, name: name, object: nil)
    }
    addObserver(NSWorkspace.didActivateApplicationNotification,
                #selector(exec.appActivateAction(_:)))
    addObserver(NSWorkspace.didDeactivateApplicationNotification,
                #selector(exec.appDeactivateAction(_:)))
    addObserver(NSWorkspace.didTerminateApplicationNotification,
                #selector(exec.appTerminalAction(_:)))
    
    deInitFunc.append {
        NSWorkspace.shared.notificationCenter.removeObserver(exec)
    }
}

class WindowAction {
    
    // ------------------------------------ //
    // static function
    
    static func percent(_ windowElement: AXUIElement, widthPercent: Double, heightPercent: Double = 1) {
        guard let screen = NSScreen.screens.first?.visibleFrame else {
            debugPrint("centerWindow: get screen failed!")
            return
        }
        
        let adjustX = round(screen.size.width * (1 - widthPercent) / 2)
        let adjustY = round(screen.size.height * (1 - heightPercent) / 2)
        let point = CGPoint(x: adjustX, y: adjustY)
        
        let width = round(screen.size.width * widthPercent)
        let height = round(screen.size.height * heightPercent)
        let size = CGSize(width: width, height: height)
        
        move(windowElement, point: point)
        resize(windowElement, size: size)
    }
    
    static func center(_ windowElement: AXUIElement) {
        guard let screen = NSScreen.screens.first?.visibleFrame else {
            debugPrint("centerWindow: get screen failed!")
            return
        }
        guard let currentWindowSize = getWindowSize(winEle: windowElement) else {
            debugPrint("centerWindow: get current window size failed!")
            return
        }
        let adjustX = (screen.size.width - currentWindowSize.width) / 2.0
        let adjustY = (screen.size.height - currentWindowSize.height) / 2.0
        let point = CGPoint(x: adjustX, y: adjustY)
        move(windowElement, point: point)
    }
    
    static func move(_ windowElement: AXUIElement, point: CGPoint) {
        var p = point
        if let v = AXValueCreate(AXValueType.cgPoint, &p) {
            main.async {
                let res = AXUIElementSetAttributeValue(windowElement, NSAccessibility.Attribute.position.rawValue as CFString, v)
                if res != .success {
                    debugPrint("move window failed!")
                }
            }
        }
    }
    
    static func resize(_ windowElement: AXUIElement, size: CGSize) {
        var s = size
        if let v = AXValueCreate(AXValueType.cgSize, &s) {
            main.async {
                let res = AXUIElementSetAttributeValue(windowElement, NSAccessibility.Attribute.size.rawValue as CFString, v)
                if res != .success {
                    debugPrint("resize window failed!")
                }
            }
        }
    }
    
    static func getMainWindowElement(_ applicationElement: AXUIElement) -> AXUIElement? {
        // main window
        var windowElementBuf: AnyObject?
        let res = AXUIElementCopyAttributeValue(applicationElement, NSAccessibility.Attribute.mainWindow.rawValue as CFString, &windowElementBuf)
        guard res == .success else {
            return nil
        }
        if windowElementBuf != nil {
            return (windowElementBuf as! AXUIElement)
        }
        return nil
    }
    
    static func getSingleWindowElement(_ applicationElement: AXUIElement) -> AXUIElement? {
        var windowElementBuf: AnyObject?
        // focused window
        var res = AXUIElementCopyAttributeValue(applicationElement, NSAccessibility.Attribute.focusedWindow.rawValue as CFString, &windowElementBuf)
        guard res == .success else {
            return nil
        }
        if windowElementBuf != nil {
            return (windowElementBuf as! AXUIElement)
        }
        
        // main window
        res = AXUIElementCopyAttributeValue(applicationElement, NSAccessibility.Attribute.mainWindow.rawValue as CFString, &windowElementBuf)
        guard res == .success else {
            return nil
        }
        if windowElementBuf != nil {
            return (windowElementBuf as! AXUIElement)
        }
        
        // single window
        if windowElementBuf == nil {
            windowElementBuf = getAllWindowElement(applicationElement)?.first
        }
        
        guard windowElementBuf != nil else {
            return nil
        }
        return (windowElementBuf as! AXUIElement)
    }
    
    static func getAllWindowElement(_ applicationElement: AXUIElement) -> [AXUIElement]? {
        var windowElementBuf: AnyObject?
        let res = AXUIElementCopyAttributeValue(applicationElement, NSAccessibility.Attribute.windows.rawValue as CFString, &windowElementBuf)
        if res != .success {
            return nil
        }
        if windowElementBuf == nil {
            return nil
        }
        let ret = windowElementBuf as! [AXUIElement]
        return ret
    }
    
    static func getFrontMostWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appele = AXUIElementCreateApplication(app.processIdentifier)
        guard let win = getSingleWindowElement(appele) else { return nil}
        return win
    }
    
    private static func getWindowSize(winEle: AXUIElement) -> CGSize? {
        var value: AnyObject?
        let res = AXUIElementCopyAttributeValue(winEle, NSAccessibility.Attribute.size.rawValue as CFString, &value)
        if res != .success {
            return nil
        }
        guard let size: CGSize = toValue(ax: value as! AXValue) else {
            return nil
        }
        return size
    }
    
    static func isWindowMinimized(window: AXUIElement) -> Bool {
        var minimized: AnyObject?
        let minimizedAttribute = kAXMinimizedAttribute as CFString
        let result = AXUIElementCopyAttributeValue(window, minimizedAttribute, &minimized)
        
        if result == .success, let isMinimized = minimized as? Bool {
            return isMinimized
        }
        return false
    }
    
    static func getSelectedText() -> String? {
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            let axuapp = AXUIElementCreateApplication(pid)
            var axuFocused: AnyObject?
            var axuSelected: AnyObject?
            if AXUIElementCopyAttributeValue(axuapp, NSAccessibility.Attribute.focusedUIElement.rawValue as CFString, &axuFocused) == .success &&
                AXUIElementCopyAttributeValue(axuFocused as! AXUIElement, NSAccessibility.Attribute.selectedText.rawValue as CFString, &axuSelected) == .success
            {
                if let selectText = axuSelected as? String {
                    return selectText
                }
            }
        }
        return nil
    }
    
    private static func toValue<T>(ax: AXValue) -> T? {
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        let success = AXValueGetValue(ax, AXValueGetType(ax), pointer)
        let value = pointer.pointee
        pointer.deallocate()
        return success ? value : nil
    }
    
    // ------------------------------------ //
    // instance method
    private struct msg {
        var axu: AXUIElement
        var appName: String
        var pid: pid_t
        
        var cnt: Int
    }
    
    private var applicationElement = [msg]()
    private var readOnlyPID = Set<pid_t>()
    private var readOnlyOk = ManagedAtomic<Int>(1)
    private let lock = DispatchSemaphore(value: 1)
    private var activatedAppliction = Set<String>()
    
    private var go = DispatchQueue.global()
    
    func start() {
        go.async { [self] in
            var idx = 0
            let iter = 10
            while true {
                self.lock.wait()
                
                guard let msg = applicationElement.first else {
                    redo(); continue
                }
                
                let appName = msg.appName
                let appElement = msg.axu
                
                guard let windowElement = WindowAction.getSingleWindowElement(appElement) else {
                    //                    debugPrint("find empty window for " + appName)
                    replayApplicationElement()
                    redo(); continue
                }
                
                WindowAction.center(windowElement)
                
                debugPrint("center executed: " + appName)
                activatedAppliction.insert(appName) // @audit data race
                
                
                // remove msg
                let removed = applicationElement.removeFirst()
                removeReadOnlyPID(removed)
                
                // update readyonlypid
                updateReadOnlyPid()
                
                redo()
                
                // ------------------------------------ //
                // internal function
                
                func replayApplicationElement() {
                    var removed = applicationElement.removeFirst()
                    removed.cnt += 1
                    if removed.cnt > 50 {
                        debugPrint(removed.appName + " cnt is " + String(removed.cnt))
                    } else {
                        self.applicationElement.append(removed)
                    }
                }
                
                
                
                func updateReadOnlyPid() {
                    idx += 1
                    if idx == iter {
                        idx = 0
                        for _ in 0..<5 {
                            let (ok, old) = readOnlyOk.compareExchange(expected: 1, desired: 0, ordering: AtomicUpdateOrdering.acquiring)
                            if !ok {
                                continue
                            }
                            
                            applicationElement
                                .filter({$0.cnt > 20})
                                .forEach({readOnlyPID.insert($0.pid)})
                            readOnlyOk.store(old, ordering: AtomicStoreOrdering.releasing)
                            break
                        }
                    }
                }
                
                
                func redo() {
                    lock.signal()
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }
    }
    
    @objc func appActivateAction(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            //            debugPrint("activate: " + app.localizedName!)
            
            // quick path
            // nowindown application will trigger frequently
            let (ok, _) = readOnlyOk.compareExchange(expected: 1, desired: 1, ordering: AtomicUpdateOrdering.acquiring)
            if ok && readOnlyPID.contains(app.processIdentifier) {
                return
            }
            
            guard let appName = app.localizedName else {
                debugPrint("get app name failed!")
                return
            }
            
            if activatedAppliction.contains(appName) {
                return // activated application don't need callback action.
            }
            
            lock.wait()
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            if applicationElement.filter({$0.appName == appName}).count != 0 {
                lock.signal()
                return
            }
            let imsg = msg(axu: appElement, appName: appName, pid: app.processIdentifier, cnt: 0)
            applicationElement.append(imsg)
            lock.signal()
        }
    }
    
    @objc func appDeactivateAction(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            //            debugPrint("deactivate: " + app.localizedName!)
            
            guard let appName = app.localizedName else {
                debugPrint("get app name failed!")
                return
            }
            
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            if let windows = WindowAction.getAllWindowElement(appElement) {
                if windows.isEmpty {
                    lock.wait()
                    if activatedAppliction.contains(appName) {
                        debugPrint("remove: " + appName)
                        activatedAppliction.remove(appName)
                    }
                    lock.signal()
                }
            }
        }
    }
    
    @objc func appTerminalAction(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        guard let appName = app.localizedName else {
            debugPrint("get app name failed!")
            return
        }
        
        lock.wait()
        if activatedAppliction.contains(appName) {
            debugPrint("remove: " + appName)
            activatedAppliction.remove(appName)
        }
        
        lock.signal()
        
    }
    
    
    private func removeReadOnlyPID(_ toRemove: msg) {
        let v = readOnlyPID.filter({$0 == toRemove.pid})
        if v.count > 0 {
            var c = 0
            for _ in 0..<20 {
                c += 1
                let (ok, old) = readOnlyOk.compareExchange(expected: 1, desired: 0, ordering: AtomicUpdateOrdering.acquiring)
                if !ok {
                    continue
                }
                self.readOnlyPID.remove(v.first!)
                self.readOnlyOk.store(old, ordering: AtomicStoreOrdering.releasing)
                break
            }
            if c == 20 {
                debugPrint("panic")
                exit(-100)
            }
        }
    }
}
