//
//  ChangeInputSource.swift
//  ohmymac
//
//  Created by Hua on 2025/8/26.
//

import Foundation
import Carbon

func switchInputSource(inputSourceID: String) {
    guard let inputSources = TISCreateInputSourceList(nil, false).takeRetainedValue() as? [TISInputSource] else {
        debug("Failed to get input sources")
        return
    }
    
    for inputSource in inputSources {
        if let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
            let sourceIDString = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
            if sourceIDString == inputSourceID {
                let status = TISSelectInputSource(inputSource)
                if status != noErr {
                    debug("Failed to switch input source")
                } else {
                    debug("Successfully switched input source to \(inputSourceID)")
                }
                return
            }
        }
    }
    debug("Input source with ID \(inputSourceID) not found")
}

let doublePinyinSourceID = "com.apple.inputmethod.SCIM.Shuangpin"
let englishSourceID = "com.apple.keylayout.ABC"

func setInputSourceToZh() {
    switchInputSource(inputSourceID: doublePinyinSourceID)
}

func setInputSourceToEn() {
    switchInputSource(inputSourceID: englishSourceID)
}
