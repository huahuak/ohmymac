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
let event = DispatchQueue(label: "background", qos: .userInteractive)

var deInitFunc: [Fn] = [{
    notify(msg: "Bye~")
}]

class ErrCode: Error {
    static let NoPermission: Int32 = -200
    static let Err: Int32 = -1
    
    static let RetryErr = ErrCode()
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

func getCurrentTimestampInMilliseconds() -> Int64 {
    var timeval = timeval()
    gettimeofday(&timeval, nil)
    let milliseconds = Int64(timeval.tv_sec) * 1000 + Int64(timeval.tv_usec) / 1000
    return milliseconds
}

func retry(f: () throws -> Void, times: UInt8 = 3) {
    if times <= 0 {
        debug("retry timeout");
        return
    }
    let interval: Double = 0.5
    do {
        try f()
    } catch {
        Thread.sleep(forTimeInterval: interval)
        retry(f: f, times: times - 1)
    }
}
