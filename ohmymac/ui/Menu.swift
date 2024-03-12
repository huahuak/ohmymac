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
    let busyBtn = {
        return createMenuButton(NSImage(systemSymbolName: "rays", accessibilityDescription: nil)!)
    }()
    var viewRecords: [NSView] = []
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: CGFloat(24))
        view = NSStackView(frame: NSRect(x: 0, y: 0, width: 72, height: 24))
        view.orientation = .horizontal
        view.distribution = .fillEqually
        statusItem.button?.addSubview(view)
    }
    
    func show(_ v: NSView) {
        view.subviews.removeAll(where: { target in target == v})
        if view.subviews.count > 2 {
            viewRecords.append(view.subviews.removeFirst())
        }
        view.addArrangedSubview(v)
        statusItem.length = CGFloat(view.subviews.count * 24)
        view.frame.size.width = CGFloat(view.subviews.count * 24)
    }
    
    func clean(_ v: NSView) {
        view.subviews.removeAll(where: { target in target == v})
        if viewRecords.count > 0 {
            view.insertArrangedSubview(viewRecords.removeLast(), at: 0)
        }
        statusItem.length = CGFloat(view.subviews.count * 24)
        view.frame.size.width = CGFloat(view.subviews.count * 24)
    }
    
    func busy() {
        show(busyBtn)
    }
    
    func free() {
        clean(busyBtn)
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



