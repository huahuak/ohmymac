//
//  Notification.swift
//  ohmymac
//
//  Created by Hua on 2024/8/29.
//

import UserNotifications

fileprivate var nc: NotificationCenter? = nil

func registryNotificationCenter() {
    nc = NotificationCenter()
    UNUserNotificationCenter.current().delegate = nc
}


// MARK: public api
func notify(msg: String, callback: Fn? = nil) {
    let content = UNMutableNotificationContent()
    content.title = "Oh My Mac"
    content.body = msg
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let uuid = UUID().uuidString;
    if let fn = callback,
       let notificationCenter = nc {
        notificationCenter.id2callback[uuid] = fn
    }
    let request = UNNotificationRequest(identifier: uuid, content: content, trigger: trigger)
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Error adding notification request: \(error.localizedDescription)")
        } else {
            print("Notification request added successfully")
        }
    }
}

// MARK: notification center
fileprivate class NotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    var id2callback: Dictionary<String, Fn> = Dictionary()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        if let fn = id2callback.first(where: { item in return item.key == id })?.value {
            fn()
        }
        id2callback.removeValue(forKey: id)
        completionHandler()
    }
}

