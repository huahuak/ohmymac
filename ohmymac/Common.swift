//
//  Common.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/25.
//

import Cocoa



let main = DispatchQueue.main
let global = DispatchQueue.global()

var deInitFunc = [() -> ()]()

class ErrCode {
    static let NoPermission: Int32 = -200
}
