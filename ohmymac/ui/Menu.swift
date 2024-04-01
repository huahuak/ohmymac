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
    var trackArea: NSTrackingArea?
    let trackAreaLock = Lock()
    let busyBtn = {
        return createMenuButton(NSImage(systemSymbolName: "rays", accessibilityDescription: nil)!)
    }()
    let busyBtnLock = Lock()
    var viewRecordsStack: [NSView] = []
    let maxLimit = 3
    
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: CGFloat(24))
        view = NSStackView(frame: NSRect(x: 0, y: 0, width: 72, height: 22))
        view.orientation = .horizontal
        view.distribution = .fillEqually
        guard let button = statusItem.button else { return }
        button.addSubview(view)
        trackArea = NSTrackingArea(
            rect: button.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        button.addTrackingArea(trackArea!)
//        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
//        button.action = #selector(menuBtnClick(_:))
//        button.target = self
    }

//    @objc func menuBtnClick(_ sender: NSButton) {
//        if let event = NSApp.currentEvent {
//            let point = statusItem.button?.convert(event.locationInWindow, from: nil)
//            view.arrangedSubviews.forEach({v in
//                if let subButton = v as? NSButton,
//                   subButton.frame.contains(point!) {
//                    subButton.sendAction(subButton.action, to: subButton.target)
//                }
//            })
//        }
//    }
    
    @objc(mouseEntered:) func mouseEntered(with event: NSEvent) {
        if !trackAreaLock.lock() { return }
        showAll()
    }
    
    @objc(mouseExited:) func mouseExited(with event: NSEvent) {
        if !trackAreaLock.unlock() { return }
        showOnlyLimit()
    }
    
    func show(_ v: NSView) {
        view.subviews.removeAll(where: { target in target == v })
        viewRecordsStack.removeAll(where: { target in target == v })
        while view.subviews.count > maxLimit - 1 {
            viewRecordsStack.append({
                let first = view.arrangedSubviews.first!
                view.removeArrangedSubview(first)
                first.removeFromSuperview()
                return first
            }())
        }
        view.addArrangedSubview(v)
        update()
    }
    
    func clean(_ v: NSView) {
        view.subviews.removeAll(where: { target in target == v})
        viewRecordsStack.removeAll(where: { target in target == v})
        while view.subviews.count < maxLimit && viewRecordsStack.count > 0 {
            view.insertArrangedSubview(viewRecordsStack.removeLast(), at: 0)
        }
        update()
    }
    
    func busy() {
        if busyBtnLock.lock() {
            show(busyBtn)
        } else {
            busyBtnLock.p()
        }
    }
    
    func free() {
        if busyBtnLock.unlock() {
            clean(busyBtn)
        } else {
            busyBtnLock.v()
        }
        
    }
    
    func showAll() {
        viewRecordsStack.reversed().forEach({ item in view.insertArrangedSubview(item, at: 0)})
        viewRecordsStack.removeAll()
        update()
    }
    
    func showOnlyLimit() {
        while view.subviews.count > maxLimit {
            viewRecordsStack.append({
                let first = view.arrangedSubviews.first!
                view.removeArrangedSubview(first)
                first.removeFromSuperview()
                return first
            }())
        }
        update()
    }
    
    private func update() {
        statusItem.length = CGFloat(view.subviews.count * 24)
        view.frame.size.width = CGFloat(view.subviews.count * 24)
        if let trackArea = trackArea,
           let button = statusItem.button {
            button.removeTrackingArea(trackArea)
            self.trackArea = NSTrackingArea(
                rect: button.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
            button.addTrackingArea(self.trackArea!)
        }
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



