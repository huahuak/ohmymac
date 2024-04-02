//
//  Logger.swift
//  ohmymac
//
//  Created by huahua on 2024/4/3.
//

import Foundation

let DEBUG = true

func debug(msg: String) {
    if !DEBUG { return }
    notify(msg: msg)
}
