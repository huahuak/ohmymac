//
//  TmpFile.swift
//  huahuamac
//
//  Created by huahua on 2023/8/28.
//

import Foundation

// COMMENT:
// used to store something temporarily.

// MARK: - write tmp file

let tmp = {
    let tmpDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let tmp = tmpDir.appendingPathComponent("translation.html")
    FileManager.default.createFile(atPath: tmp.path, contents: "".data(using: .utf8), attributes: nil)
    debugPrint("location: " + tmp.path)
    return tmp
}()


func writeTmp(content: String) -> URL? {
    do {
        try content.write(to: tmp, atomically: false, encoding: .utf8)
    } catch let error {
        debugPrint("run shortcut failed, \(error)")
        return nil
    }
    return tmp
}
