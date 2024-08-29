//
//  ChangeInputSource.swift
//  ohmymac
//
//  Created by Hua on 2025/8/26.
//

import Foundation
import Carbon

// - BUG: macos will not working sometimes.
//func switchInputSource(inputSourceID: String) {
//    guard let inputSources = TISCreateInputSourceList(nil, false).takeRetainedValue() as? [TISInputSource] else {
//        debug("Failed to get input sources")
//        return
//    }
//    
//    for inputSource in inputSources {
//        if let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
//            let sourceIDString = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
//            if sourceIDString == inputSourceID {
//                _ = TISSelectInputSource(inputSource)
//                return
//            }
//        }
//    }
//    debug("Input source with ID \(inputSourceID) not found")
//}

let doublePinyinSourceID = "com.apple.inputmethod.SCIM.Shuangpin"
let englishSourceID = "com.apple.keylayout.ABC"

func executeChangeInputSource() {
    let source = CGEventSource(stateID: .hidSystemState)
    let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: Keycode.space, keyDown: true)
    let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: Keycode.space, keyDown: false)
    keyDownEvent?.flags = .maskControl
    keyUpEvent?.flags = .maskControl
    keyDownEvent?.post(tap: .cghidEventTap)
    keyUpEvent?.post(tap: .cghidEventTap)
}

func getCurrentInputSourceString() -> String {
    if let inputSource = TISCopyCurrentKeyboardInputSource()?.takeUnretainedValue(),
       let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID){
        let sourceIDString = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
        return sourceIDString
    }
    return ""
}

func setInputSourceToZh() {
    if getCurrentInputSourceString() != doublePinyinSourceID {
        executeChangeInputSource()
    }
}

func setInputSourceToEn() {
    if getCurrentInputSourceString() != englishSourceID {
        executeChangeInputSource()
    }
}
