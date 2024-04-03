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

var deInitFunc: [Fn] = []

class ErrCode: Error {
    static let NoPermission: Int32 = -200
    static let Err: Int32 = -1
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

func retry(f: () -> Bool, times: UInt8 = 3) {
    var cnt = 0
    let interval: useconds_t = 100 * 1000 // 100ms
    while cnt < times {
        if f() {
            return
        }
        cnt += 1
        usleep(interval)
    }
}
