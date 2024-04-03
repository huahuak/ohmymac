//
//  Observer.swift
//  ohmymac
//
//  Created by huahua on 2024/4/3.
//

import Foundation
import AppKit


private var AXObserverHolder: [AXObserver] = []

class EscapeFn {
    let fn: Fn
    
    init(fn: @escaping Fn) {
        self.fn = fn
    }
    
    func exec() {
        fn()
    }
}

class Observer {
    static func add(notice: Notification.Name, handler: @escaping (Notification) -> Void) {
        let observer = NSWorkspace.shared.notificationCenter
            .addObserver(forName: notice, object: nil, queue: nil, using: handler)
        deInitFunc.append({
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        })
    }
    
    static func addAX(notification: String,
                      pid: pid_t,
                      axWindow: AXUIElement,
                      fn: EscapeFn) -> Fn {
        var axObserver: AXObserver? = nil
        let fnPtr =  Unmanaged.passRetained(fn)
        func handler(observer: AXObserver,
                     element: AXUIElement,
                     notificationName: CFString,
                     ptr: UnsafeMutableRawPointer?) -> Void  {
            let fn = Unmanaged<EscapeFn>.fromOpaque(ptr!).takeUnretainedValue()
            fn.exec()
        }
        
        if AXObserverCreate(pid, handler, &axObserver) != .success {
            warn("Observer.addAX(): create failed!"); return {}
        }
        if AXObserverAddNotification(axObserver!,
                                     axWindow, notification as CFString,
                                     fnPtr.toOpaque()) != .success {
            warn("Observer.addAX(): add failed!"); return {}
        }
        CFRunLoopAddSource(RunLoop.current.getCFRunLoop(),
                           AXObserverGetRunLoopSource(axObserver!),
                           CFRunLoopMode.defaultMode)

        let deinitCallback = {
            CFRunLoopRemoveSource(RunLoop.current.getCFRunLoop(),
                                  AXObserverGetRunLoopSource(axObserver!),
                                  CFRunLoopMode.defaultMode)
            if AXObserverRemoveNotification(axObserver!, axWindow, notification as CFString) != .success {
                warn("Observer.addAX(): remove failed!")
            }
            axObserver = nil
            fnPtr.release()
        }  // deinit by caller
        return deinitCallback
    }
}
