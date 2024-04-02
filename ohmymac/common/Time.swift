//
//  Time.swift
//  ohmymac
//
//  Created by huahua on 2024/4/2.
//

import Foundation

func getCurrentTimestampInMilliseconds() -> Int64 {
    var timeval = timeval()
    gettimeofday(&timeval, nil)
    let milliseconds = Int64(timeval.tv_sec) * 1000 + Int64(timeval.tv_usec) / 1000
    return milliseconds
}
