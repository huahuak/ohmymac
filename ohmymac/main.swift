//
//  main.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/23.
//

import AppKit

signal(SIGTERM) { _ in
    deInitFunc.forEach{ $0() }
    exit(0)
}

let ohmymacApp = NSApplication.shared
let menu = Menu()
let delegate = AppDelegate()
ohmymacApp.delegate = delegate
ohmymacApp.run()
