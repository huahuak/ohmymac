//
//  GoogleSearch.swift
//  huahuamac
//
//    by huahua on 2023/8/28.
//

import Foundation

func googleSearchURL(content: String) -> URL? {
    guard let googleURL = URL(string: "https://www.google.com.hk/search?client=safari&rls=en&q=\(content)&ie=UTF-8&oe=UTF-8") else {
        return nil
    }
    return googleURL
}

