//
//  main.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/23.
//

import AppKit

let ohmymacApp = NSApplication.shared
let menu = Menu()
let delegate = AppDelegate()
ohmymacApp.delegate = delegate
ohmymacApp.run()
