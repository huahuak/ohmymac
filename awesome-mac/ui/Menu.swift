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
    }
    return statusItem
}

func randomIcon() -> String {
    let iconString = """
        figure.american.football
        figure.archery
        figure.australian.football
        figure.badminton
        figure.barre
        figure.baseball
        figure.basketball
        figure.bowling
        figure.boxing
        figure.climbing
        figure.cooldown
        figure.core.training
        figure.cricket
        figure.skiing.crosscountry
        figure.cross.training
        figure.curling
        figure.dance
        figure.disc.sports
        figure.skiing.downhill
        figure.elliptical
        figure.equestrian.sports
        figure.fencing
        figure.fishing
        figure.flexibility
        figure.strengthtraining.functional
        figure.golf
        figure.gymnastics
    """
    let iconList = iconString.split(separator: "\n").map({ $0.trimmingCharacters(in: [" "])})
    return iconList[Int.random(in: 0...iconList.count-1)]
}
