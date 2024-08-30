//
//  GoogleSearch.swift
//  huahuamac
//
//    by huahua on 2023/8/28.
//

import Foundation

func googleSearch() {
    getScreenText { text in
        let googleURL = URL(string: "https://www.google.com.hk/search?client=safari&rls=en&q=\(text)&ie=UTF-8&oe=UTF-8")!
        openQuickLook(file: googleURL)
    }
}

