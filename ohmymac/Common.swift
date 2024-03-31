//
//  Common.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/25.
//

import Cocoa
import UserNotifications

typealias Fn = () -> Void

let main = DispatchQueue.main
let global = DispatchQueue.global()

var deInitFunc = [() -> ()]()

class ErrCode {
    static let NoPermission: Int32 = -200
    static let Err: Int32 = -1
}

class Lock {
    var locked = 0
    let before: Fn?
    let after: Fn?
    
    init(before: Fn? = nil, after: Fn? = nil) {
        self.before = before
        self.after = after
    }
    
    func lock() -> Bool {
        if locked >= 1 { return false }
        locked = 1;
        before?()
        return true
    }
    
    func unlock() -> Bool {
        if locked == 0 || locked != 1 { return false }
        locked = 0;
        after?()
        return true
    }
    
    func p() {
        locked += 1
    }
    
    func v() {
        if locked == 0 { return }
        locked -= 1
    }
}

func notify(msg: String) {
    let content = UNMutableNotificationContent()
    content.title = "ohmymac"
    content.body = msg
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(identifier: "notificationIdentifier", content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Error adding notification request: \(error.localizedDescription)")
        } else {
            print("Notification request added successfully")
        }
    }

}

extension NSImage {
    func convertToGrayScale() -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIColorControls")!
        filter.setDefaults()
        filter.setValue(ciImage, forKey: "inputImage")
        filter.setValue(0.0, forKey: "inputSaturation")

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let rep = NSCIImageRep(ciImage: outputImage)
        let nsImage = NSImage(size: self.size)
        nsImage.addRepresentation(rep)

        return nsImage
    }
}
