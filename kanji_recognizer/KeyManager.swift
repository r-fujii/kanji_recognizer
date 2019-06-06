//
//  KeyManager.swift
//  kanji_recognizer
//
//  Created by Ryo Fujii on 2019/06/01.
//  Copyright © 2019 Ryo Fujii. All rights reserved.
//

import Foundation

struct KeyManager {
    
    private let keyFilePath = Bundle.main.path(forResource: "keys", ofType: "plist")
    
    func getKeys() -> NSDictionary? {
        guard let keyFilePath = keyFilePath else {
            return nil
        }
        return NSDictionary(contentsOfFile: keyFilePath)
    }
    
    func getValue(key: String) -> AnyObject? {
        guard let keys = getKeys() else {
            return nil
        }
        return keys[key]! as AnyObject
    }
    
}
