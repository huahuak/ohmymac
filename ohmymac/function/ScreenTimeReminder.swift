//
//  ScreenTimer.swift
//  ohmymac
//
//  Created by Hua on 2024/8/29.
//
import Foundation
import AppKit

private var timer: Timer? = nil
private var count = 0;

func startScreenTimeReminder(interval: TimeInterval) {
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            count += 1;
            notify(msg: "Look away! You've been staring at the screen for \(Int(interval) * count / 3600) hour.") {
                count = 0;
            }
            startTimer()
        }
    }
    
    startTimer()
    
    Observer.addGlobally(notice: NSWorkspace.screensDidWakeNotification) { _ in
        debugPrint("wake")
        startTimer()
    }
    Observer.addGlobally(notice: NSWorkspace.screensDidSleepNotification) { _ in
        debugPrint("sleep")
        count = 0;
        timer?.invalidate()
        timer = nil
    }
}
