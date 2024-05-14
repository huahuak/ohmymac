//
//  Observer.swift
//  ohmymac
//
//  Created by huahua on 2024/4/3.
//

import Foundation
import AppKit


private var AXObserverHolder: [AXObserver] = []

typealias ObserverHandlerFn = (AXUIElement) -> Void

class EscapeObserverExecutor {
    let fn: ObserverHandlerFn?
    
    init(fn: @escaping ObserverHandlerFn) {
        self.fn = fn
    }
}

class Observer {
    static func addGlobally(notice: Notification.Name, handler: @escaping (Notification) -> Void) {
        let observer = NSWorkspace.shared.notificationCenter
            .addObserver(forName: notice, object: nil, queue: nil) {
                debug("Global Notification: \(notice)")
                handler($0)
            }
        deInitFunc.append({
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        })
    }
    
    static func addLocally(notice: Notification.Name, handler: @escaping (Notification) -> Void) {
        let observer = NotificationCenter.default
            .addObserver(forName: notice, object: nil, queue: nil) {
                debug("Locally Notification: \(notice)")
                handler($0)
            }
        deInitFunc.append({
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        })
    }
    
    static func add(notifications: [String],
                      pid: pid_t,
                      axui: AXUIElement,
                      fn: EscapeObserverExecutor) -> Fn {
        let fnPtr =  Unmanaged.passRetained(fn)
        func handler(observer: AXObserver,
                     element: AXUIElement,
                     notificationName: CFString,
                     ptr: UnsafeMutableRawPointer?) -> Void  {
            debug("AX Notification: \(notificationName)")
            guard let ptr = ptr else { return }
            let executor = Unmanaged<EscapeObserverExecutor>.fromOpaque(ptr).takeUnretainedValue()
            guard let fn = executor.fn else {
                // debug coding
                warn("Observer.add(): fn is nil")
                notify(msg: "Observer.add(): fn is nil")
                return
            }
            fn(element)
        }
        
        var axObserver: AXObserver? = nil
        if AXObserverCreate(pid, handler, &axObserver) != .success {
            warn("Observer.add(): create failed!"); return {}
        }
        notifications.forEach {
            if AXObserverAddNotification(axObserver!,
                                         axui, $0 as CFString,
                                         fnPtr.toOpaque()) != .success {
                warn("Observer.add(): add failed!");
            }
        }
        
        main.async { // TODO: move runloop to background thread, to improve performance.
            CFRunLoopAddSource(RunLoop.current.getCFRunLoop(),
                               AXObserverGetRunLoopSource(axObserver!),
                               CFRunLoopMode.defaultMode)
        }

        let deinitCallback = {
//            // for now we don't call release by self.
//            notifications.forEach {
//                let result = AXObserverRemoveNotification(axObserver!, axui, $0 as CFString)
//                if  result != .success {
//                    warn("Observer.add(): remove failed! result is \(result.rawValue)")
//                }
//            }
//            CFRunLoopRemoveSource(RunLoop.current.getCFRunLoop(),
//                                  AXObserverGetRunLoopSource(axObserver!),
//                                  CFRunLoopMode.defaultMode)
            axObserver = nil
            fnPtr.release()
        }  // deinit by caller
        return deinitCallback
    }
}
