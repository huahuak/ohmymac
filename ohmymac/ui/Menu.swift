//
//  Menu.swift
//  huahuamac
//
//  Created by huahua on 2023/8/27.
//

import Cocoa

// COMMENT:
// menu is used to set menu icon.


func huahuamacMenu() -> NSStatusItem {
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    if let button = statusItem.button {
        button.image = NSImage(systemSymbolName: randomIcon(), accessibilityDescription: nil)
        button.action = #selector(AppDelegate.buttonClicked)
    }
    return statusItem
}

extension AppDelegate { // TODO, remove buttonClicked function from AppDelegate
    @objc func buttonClicked(sender: NSStatusBarButton) {
        sender.image = NSImage(systemSymbolName: randomIcon(), accessibilityDescription: nil)
    }
}



func randomIcon() -> String {
    let iconString = """
    figure.walk
    figure.run
    figure.archery
    figure.badminton
    figure.baseball
    figure.bowling
    figure.boxing
    figure.climbing
    figure.snowboarding
    figure.soccer
    figure.highintensity.intervaltraining
    figure.pool.swim
    figure.open.water.swim
    command
    """
    let iconList = iconString.split(separator: "\n").map({ $0.trimmingCharacters(in: [" "])})
    
    return iconList[Int.random(in: 0...iconList.count-1)]
}



