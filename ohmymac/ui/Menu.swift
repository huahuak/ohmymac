//
//  Menu.swift
//  huahuamac
//
//  Created by huahua on 2023/8/27.
//

import Cocoa

// COMMENT:
// menu is used to set menu icon.

class Menu {
    let statusItem: NSStatusItem
    let view: NSStackView
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: CGFloat(72))
        statusItem.button?.action = #selector(AppDelegate.buttonClicked)
        
        view = NSStackView(frame: NSRect(x: 0, y: 0, width: 72, height: 24))
        view.orientation = .horizontal
//                view.spacing = 2
        view.distribution = .fillEqually
        view.addArrangedSubview(createMenuButton(randomIcon()))
        view.addArrangedSubview(createMenuButton(randomIcon()))
        view.addArrangedSubview(createMenuButton(randomIcon()))
        statusItem.button?.addSubview(view)
    }
    
    func show(_ v: NSView) {
        view.subviews.removeAll(where: { target in target == v})
        if view.subviews.count > 2 {
            view.subviews.removeFirst()
        }
        view.addArrangedSubview(v)
    }
    
    func clean(_ v: NSView) {
        view.subviews.removeAll(where: { target in target == v})
        if view.subviews.count < 3 {
            view.insertArrangedSubview(createMenuButton(randomIcon()), at: 0)
        }
    }
    
    func busy() {
        statusItem.button?.image = NSImage(systemSymbolName: "rays", accessibilityDescription: nil)
    }
    
    func free() {
        //        statusItem.button?.image = oldImg
    }
}

extension AppDelegate {
    @objc func buttonClicked(sender: NSStatusBarButton) {
        //        sender.image = randomIcon()
    }
}

func createMenuButton(_ img: NSImage) -> NSButton {
    let button = NSButton(frame: NSRect(x: 0, y: 0, width: 26, height: 26))
    button.image = img
    button.isBordered = false
    return button
}

func randomIcon() -> NSImage {
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
    """
    let iconList = iconString.split(separator: "\n").map({ $0.trimmingCharacters(in: [" "])})
    return NSImage(systemSymbolName: iconList[Int.random(in: 0...iconList.count-1)], accessibilityDescription: nil)!
    
}



