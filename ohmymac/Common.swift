//
//  Common.swift
//  WindowActionCallback
//
//  Created by huahua on 2023/8/25.
//

import Cocoa


typealias Fn = () -> Void

let main = DispatchQueue.main
let global = DispatchQueue.global()

var deInitFunc = [() -> ()]()

class ErrCode {
    static let NoPermission: Int32 = -200
}

class Lock {
    var locked = 0
    let before: Fn?
    let after: Fn?
    
    init(before: Fn? = nil, after: Fn? = nil) {
        self.before = before
        self.after = after
    }
    
    func lock() -> Bool {
        if locked >= 1 { return false }
        locked = 1;
        before?()
        return true
    }
    
    func unlock() -> Bool {
        if locked == 0 || locked != 1 { return false }
        locked = 0;
        after?()
        return true
    }
    
    func p() {
        locked += 1
    }
    
    func v() {
        if locked == 0 { return }
        locked -= 1
    }
}
