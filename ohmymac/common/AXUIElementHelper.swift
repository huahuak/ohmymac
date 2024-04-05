//
//  AXWindow.swift
//  ohmymac
//
//  Created by huahua on 2024/3/31.
//

import Foundation
import Cocoa
import Carbon

extension AXUIElement {
    private func get<T>(str: String) -> T? {
        var value: AnyObject?
        let attribute = str as CFString
        let result = AXUIElementCopyAttributeValue(self, attribute, &value)
        if result == .success {
            return (value as! T)
        }
        warn("AXUIElement.get(): get attr: \(str) failed, err is \(result.rawValue)")
        return nil
    }
    
    private func get<T>(attr: NSAccessibility.Attribute) -> T? {
        get<T>(str: attr.rawValue)
    }
    
    func subrole() -> String? {
        get(attr: .subrole)
    }
    
    // ------------------------------------ //
    // for space
    // ----------------------------------- //
    static func spaceID() -> Int? {
        if let mainScreen = NSScreen.main,
           let uuid = mainScreen.uuid() {
            return Int(CGSManagedDisplayGetCurrentSpace(conn, uuid))
        }
        return nil
    }
    
    // ------------------------------------ //
    // for window
    // ----------------------------------- //
    func isFullScreent() -> Bool? {
        get(str: kAXFullscreenAttribute)
    }
    
    func isMinimized() -> Bool? {
        get(attr: .minimized)
    }
    
    func isMainWindow() -> Bool? {
        get(attr: .main)
    }
    
    @discardableResult
    func minimize() -> Bool {
        let result = AXUIElementSetAttributeValue(self, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        if result != .success {
            warn("AXUIElement.minimize(): minize failed for \(String(describing: windowTitle()))")
        }
        return result == .success
    }
    
    func windowSize() -> CGSize? {
        if let attr: AXValue = get(attr: .size) {
            var size = CGSize.zero
            AXValueGetValue(attr, .cgSize, &size)
            return size
        }
        return nil
    }
    
    func windowID() -> CGWindowID? {
        var wid: CGWindowID = 0
        let result = _AXUIElementGetWindow(self, &wid)
        if result == .success {
            return wid
        }
        warn("AXUIElement.windowID(): failed!")
        return nil
    }
    
    func windowLevel() -> CGWindowLevel? {
        var level = CGWindowLevel(0)
        if let ID = windowID() {
            CGSGetWindowLevel(conn, ID, &level)
            return level
        }
        return nil
    }
    
    func windowTitle() -> String? {
        get(attr: .title)
    }
    
    func spaceID4Window() -> Int? {
        if let windowID = windowID(),
           let spaces = CGSCopySpacesForWindows(conn, CGSSpaceMask.all.rawValue, [windowID] as CFArray) as? [CGSSpaceID],
           let firstSpaceID = spaces.first {
            return Int(firstSpaceID)
        }
        return nil
    }
    
    // ------------------------------------ //
    // for application
    // ----------------------------------- //
    
    func getMainWindow() -> AXUIElement? {
        get(attr: .mainWindow)
    }
    
    func getFocusedWindow() -> AXUIElement? {
        get(attr: .focusedWindow)
    }
    
    func getAllWindows() -> [AXUIElement]? {
        get(attr: .windows)
    }

    
}

// ------------------------------------ //
// thanks to https://alt-tab-macos.netlify.app
// ----------------------------------- //
extension NSScreen {
    func uuid() -> CFString? {
        if let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")],
           // these APIs implicitly unwrap their return values, but it can actually be nil thus we check
           let screenUuid = CGDisplayCreateUUIDFromDisplayID(screenNumber as! UInt32),
           let uuid = CFUUIDCreateString(nil, screenUuid.takeRetainedValue()) {
            return uuid
        }
        return nil
    }
}

// ------------------------------------ //
// privacy
// ----------------------------------- //
fileprivate let kAXFullscreenAttribute = "AXFullScreen"

fileprivate let conn = CGSMainConnectionID()

typealias CGSConnectionID = UInt32
typealias CGSSpaceID = UInt64
typealias ScreenUuid = CFString
enum CGSSpaceMask: Int {
    case current = 5
    case other = 6
    case all = 7
}

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("_AXUIElementGetWindow") @discardableResult
fileprivate func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError

@_silgen_name("CGSCopySpacesForWindows")
fileprivate func CGSCopySpacesForWindows(_ cid: CGSConnectionID, _ mask: CGSSpaceMask.RawValue, _ wids: CFArray) -> CFArray

@_silgen_name("CGSManagedDisplayGetCurrentSpace")
fileprivate func CGSManagedDisplayGetCurrentSpace(_ cid: CGSConnectionID, _ displayUuid: ScreenUuid) -> CGSSpaceID

@_silgen_name("CGSGetWindowLevel") @discardableResult
func CGSGetWindowLevel(_ cid: CGSConnectionID, _ wid: CGWindowID, _ level: inout CGWindowLevel) -> CGError
