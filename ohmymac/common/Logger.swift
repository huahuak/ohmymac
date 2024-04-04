//
//  Logger.swift
//  ohmymac
//
//  Created by huahua on 2024/4/3.
//

import Foundation

let DEBUG = false

func debugNotify(msg: String) {
    if !DEBUG { return }
    notify(msg: msg)
}

func warn(_ msg: String) {
    if !DEBUG { return }
    debugPrint(msg)
}

func info(_ msg: String) {
    if !DEBUG { return }
    debugPrint(msg)
}
