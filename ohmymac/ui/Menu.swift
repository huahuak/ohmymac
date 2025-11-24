//
//  Menu.swift
//  huahuamac
//
//  Created by huahua on 2023/8/27.
//

import Cocoa

// COMMENT:
// menu is used to set menu icon.
private let ICON_WIDTH = Int(NSStatusBar.system.thickness)
private let MAX_COUNT = 6

class MenuView: NSStackView {
    private var trackingTimer = Timer()
    private var longTracking: NSTrackingArea?
    
    static func getMenuView() -> MenuView {
        let view = MenuView()
        view.orientation = .horizontal
        view.distribution = .fillEqually
        view.spacing = 0
        
        view.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: view,
            userInfo: ["status": "shortTracking"])
        )
        return view
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        for view in subviews {
            if view.frame.contains(point) {
                return view
            }
        }
        return nil
    }
    
    func add(view: NSView) {
        remove(view: view)
        addArrangedSubview(view)
        updateSubviewPriority()
    }
    
    func remove(view: NSView) {
        if subviews.contains(where: { $0.isEqual(view) }) {
            removeArrangedSubview(view)
        }
        view.removeFromSuperview()
        updateSubviewPriority()
    }
    
    private func updateSubviewPriority() {
        for (idx, view) in arrangedSubviews.enumerated() {
            if idx < subviews.count - MAX_COUNT {
                view.isHidden = true
            } else {
                view.isHidden = false
            }
        }
        ohmymac.menu.statusItem.length = CGFloat(min(MAX_COUNT, subviews.count) * ICON_WIDTH)
    }
    
    // MOUSE TRACKING
    func checkMouseInside() -> Bool {
        guard let window = self.window else { return false }
        var mouseLocation = NSEvent.mouseLocation
        mouseLocation = window.convertPoint(fromScreen: mouseLocation)
        let localPoint = self.convert(mouseLocation, from: nil)
        return self.frame.contains(localPoint)
    }
    
    @objc(mouseEntered:) override func mouseEntered(with event: NSEvent) {
        if event.trackingArea?.userInfo?["status"] as? String == "shortTracking" {
            trackingTimer.invalidate()
            trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [self] _ in
                if !checkMouseInside() { return }
                ohmymac.menu.statusItem.length = CGFloat(subviews.count * ICON_WIDTH)
                for view in arrangedSubviews {
                    view.isHidden = false
                }
                main.asyncAfter(deadline: .now() + 0.15) { [self] in
                    if longTracking != nil { return }
                    longTracking = NSTrackingArea(
                        rect: .zero,
                        options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                        owner: self,
                        userInfo: ["status": "longTracking"]
                    )
                    addTrackingArea(longTracking!)
                }
            }
        }
    }
    
    @objc(mouseExited:) override func mouseExited(with event: NSEvent) {
        if event.trackingArea?.userInfo?["status"] as? String == "longTracking" {
            updateSubviewPriority()
            if let area = longTracking {
                removeTrackingArea(area)
                longTracking = nil
            }
        }
    }
}


class Menu {
    let view = MenuView.getMenuView()
    var wss =  {
        var wss = WindowSwitchShortcut()
        WindowSwitchShortcut.startCGEvent(wss: &wss)
        return wss
    }()
    let statusItem: NSStatusItem
    let busyBtn = {
        return MenuButton.createBtn(NSImage(systemSymbolName: "rays", accessibilityDescription: nil)!)
    }()
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                view.topAnchor.constraint(equalTo: button.topAnchor),
                view.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
        }
    }
    
    func show(_ v: NSView) {
        view.add(view: v)
    }
    
    func clean(_ v: NSView) {
        view.remove(view: v)
    }
    
}

class MenuButton: NSButton {
    fileprivate var rightAction: ((NSEvent) -> ())?
    fileprivate var leftAction: ((NSEvent) -> ())?

    override func rightMouseUp(with event: NSEvent) {
        rightAction?(event)
    }
    
    @objc func clickAction(_ sender: NSButton) {
        leftAction?(NSEvent())
    }
    
    static func createBtn(_ img: NSImage,
                          leftAction: ((NSEvent) -> Void)? = nil,
                          rightAction: ((NSEvent) -> Void)? = nil) -> NSButton {
        let button = MenuButton(frame: NSRect(x: 0, y: 0, width: ICON_WIDTH, height: ICON_WIDTH))
        button.image = img
        button.isBordered = false
        // click action
        button.action = #selector(clickAction(_:))
        button.target = button
        button.sendAction(on: [.leftMouseUp])
        button.leftAction = leftAction
        button.rightAction = rightAction
        return button
    }
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


// SHORTCUT FOR CMD+TAB
class WindowSwitchShortcut {
    let backgroundThread = BackgroundThread()
    
    var doing = false
    var cnt = 1
    var eventTap: CFMachPort?
    
    static func get (_ idx: Int) -> NSButton? {
        if menu.view.subviews.isEmpty { return nil }
        let reverse = menu.view.arrangedSubviews.count - 1 - (idx % min(MAX_COUNT, menu.view.arrangedSubviews.count))
        return menu.view.arrangedSubviews[reverse] as? NSButton
    }
    
    let start:() -> Void =  {
        main.async {
            Thread.sleep(forTimeInterval: 0.1)
            if let btn = get(1) {
                animate(shakeButton: btn)
            }
        }
        get(1)?.highlight(true)
    }
    
    let next: (_ idx: Int)->Void =  {idx in
        get(idx - 1)?.highlight(false)
        if let selected = get(idx) {
            selected.highlight(true)
            animate(shakeButton: selected)
        }
    }
    
    let end: (_ idx: Int) -> Void =  { idx in
        get(idx - 1)?.highlight(false)
        if let selected = get(idx) {
            selected.highlight(false)
            if let window = selected.target as? Window {
                window.focus()
            }
        }
    }
    
    private static func animate(shakeButton: NSButton) {
        shakeButton.layer?.removeAllAnimations()
        let shakeAnimation = CABasicAnimation(keyPath: "position")
        shakeAnimation.duration = 0.05
        shakeAnimation.repeatCount = 1
        shakeAnimation.autoreverses = true
        let fromPoint = CGPoint(x: shakeButton.frame.origin.x, y: shakeButton.frame.origin.y + 2)
        let toPoint = CGPoint(x: shakeButton.frame.origin.x, y: shakeButton.frame.origin.y - 2)
        shakeAnimation.fromValue = NSValue(point: fromPoint)
        shakeAnimation.toValue = NSValue(point: toPoint)
        shakeButton.layer?.add(shakeAnimation, forKey: "position")
    }
    
    // SHORTCUT FOR CMD+TAB
    static func startCGEvent(wss: inout WindowSwitchShortcut) {
        func cmdTabHandler(proxy: CGEventTapProxy, type: CGEventType,
                           event: CGEvent, userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
            let wss = Unmanaged<WindowSwitchShortcut>.fromOpaque(userInfo!).takeUnretainedValue()
            if type == .tapDisabledByTimeout {
                notify(msg: "cmd+tab shortcut was disabled by timeout!\nnow restart...")
                if let eventTap = wss.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                return nil
            }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode != KeyCodeEnum.tab && keyCode != KeyCodeEnum.command {
                return Unmanaged.passUnretained(event)
            }
            if !wss.doing && !(event.flags.contains(.maskCommand) && keyCode == KeyCodeEnum.tab) {
                return Unmanaged.passUnretained(event)
            }
            main.async {
                if !wss.doing && keyCode == KeyCodeEnum.tab && event.flags.contains(.maskCommand) { // cmd + tab
                    wss.doing = true
                    wss.start()
                    return
                }
                if wss.doing && keyCode == KeyCodeEnum.tab && event.flags.contains(.maskCommand) {
                    wss.cnt += 1
                    wss.next(wss.cnt)
                    return
                }
                if wss.doing && !event.flags.contains(.maskCommand) {
                    wss.doing = false
                    wss.end(wss.cnt)
                    wss.cnt = 1
                    return
                }
            }
            return nil
        }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let userInfo = Unmanaged.passUnretained(wss).toOpaque()
        guard let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                               place: .headInsertEventTap,
                                               options: .defaultTap,
                                               eventsOfInterest: CGEventMask(eventMask),
                                               callback: cmdTabHandler,
                                               userInfo: userInfo) else {
            print("failed to create event tap")
            exit(ErrCode.Err)
        }
        wss.eventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(wss.backgroundThread.backgroundRunLoop, runLoopSource, .defaultMode)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
}

