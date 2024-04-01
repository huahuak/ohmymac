//
//  AXWindow.swift
//  ohmymac
//
//  Created by huahua on 2024/3/31.
//

import Foundation
import Cocoa
import Carbon


fileprivate var spaceIdentifier = SpaceIdentifier()

class AXWindow {
    static func getWindowSpaceOrder(window: AXUIElement) -> Int? {
        if let id = getWindowSpaceID(window: window) {
            let allSpaces = spaceIdentifier.getSpaceInfo().allSpaces
            if let exist = allSpaces.filter({ $0.id64 == id }).first {
                return exist.number
            }
        }
        return nil
    }
    
    static func getWindowSpaceID(window: AXUIElement) -> Int? {
        var wid: CGWindowID = 0
        if _AXUIElementGetWindow(window, &wid) == .success {
            if let spaceIDs = CGSCopySpacesForWindows(CGSConnectionID(spaceIdentifier.conn), 
                                                      CGSSpaceMask.all.rawValue,
                                                      [wid] as CFArray) as? [Int] {
                return spaceIDs.first
            }
        }
        notify(msg: "getWindowSpaceOrder failed!")
        return nil
    }
    
    static func activatedSpaceOrder() -> Int? {
        if let space = spaceIdentifier.getSpaceInfo().activeSpaces.first {
            return space.number
        }
        notify(msg: "get space order failed!")
        return -1
    }
    
    static func activatedSpaceID() -> Int? {
        if let space = spaceIdentifier.getSpaceInfo().activeSpaces.first {
            return space.id64
        }
        notify(msg: "get space id failed!")
        return -1
    }
    
    static func isAlive(window: AXUIElement) -> Bool {
        var windowValue: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &windowValue) == .success &&
            windowValue != nil {
            return true
        }
        return false
    }
    
    static func isMinimized(window: AXUIElement) -> Bool {
        var minimized: AnyObject?
        let attribute = kAXMinimizedAttribute as CFString
        let result = AXUIElementCopyAttributeValue(window, attribute, &minimized)
        if result == .success,
           let minimizedValue = minimized as? Bool {
            return minimizedValue
        }
        notify(msg: "axWindow isMinimized() failed")
        return false
    }
    
    static func minimize(window: AXUIElement) -> Bool {
        let result = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        return result == .success
    }
    
    static func getMainWindow(app: AXUIElement) -> AXUIElement? {
        var windowElementBuf: AnyObject?
        let res = AXUIElementCopyAttributeValue(app, NSAccessibility.Attribute.mainWindow.rawValue as CFString, &windowElementBuf)
        if res == .success && windowElementBuf != nil {
            return (windowElementBuf as! AXUIElement)
        }
        return nil
    }
    
    static func getFocusedWindow(app: AXUIElement) -> AXUIElement? {
        var windowElementBuf: AnyObject?
        let res = AXUIElementCopyAttributeValue(app, NSAccessibility.Attribute.focusedWindow.rawValue as CFString, &windowElementBuf)
        if res == .success && windowElementBuf != nil {
            return (windowElementBuf as! AXUIElement)
        }
        return nil
    }
    
    static func getFrontMostWindow(app: AXUIElement) -> AXUIElement? {
        var windowElementBuf: AnyObject?
        let res = AXUIElementCopyAttributeValue(app, NSAccessibility.Attribute.frontmost.rawValue as CFString, &windowElementBuf)
        if res == .success && windowElementBuf != nil {
            return (windowElementBuf as! AXUIElement)
        }
        return nil
    }
    
    static func getAllWindows(app: AXUIElement) -> [AXUIElement]? {
        var windowElementBuf: AnyObject?
        if AXUIElementCopyAttributeValue(
            app, NSAccessibility.Attribute.windows.rawValue as CFString, &windowElementBuf) == .success &&
            windowElementBuf != nil {
            return windowElementBuf as? [AXUIElement]
        }
        return nil
    }
    
    static func getTitle(window: AXUIElement) -> String? {
        var windowValue: AnyObject?
        let res =  AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &windowValue)
        if res == .success && windowValue != nil {
            return windowValue as? String
        }
        return nil
    }    
    
    static func getID(window: AXUIElement) -> String? {
        var windowValue: AnyObject?
        let res =  AXUIElementCopyAttributeValue(window, kAXWindowAttribute as CFString, &windowValue)
        if res == .success && windowValue != nil {
            return windowValue as? String
        }
        return nil
    }
}

// ------------------------------------ //
// temp function
// ----------------------------------- //
typealias CGSConnectionID = UInt32
enum CGSSpaceMask: Int {
    case current = 5
    case other = 6
    case all = 7
}

@_silgen_name("CGSGetWindowWorkspace") @discardableResult
func CGSGetWindowWorkspace(_ cid: CGSConnectionID, _ wid: CGWindowID, _ workspace: [Int]) -> OSStatus

@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError

@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(_ cid: CGSConnectionID, _ mask: CGSSpaceMask.RawValue, _ wids: CFArray) -> CFArray
