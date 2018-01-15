//
//  EduTranslate.swift
//  eduhacks2017
//
//  Created by Elaine Feng on 10/1/17.
//  Copyright © 2017 Gabriel Uribe. All rights reserved.
//

import Foundation

class EduTranslate {
    static func go(words: String, callback: @escaping ([String]) -> ()) {
        let translator = ROGoogleTranslate(with: "AIzaSyC5lyG_vgfVNxs4LZzGZgJA9y7set_193Q")
        
        let wordsArr = words.components(separatedBy: ",")
        var translatedArr = [String]()
        var numResults = 0
        for word in wordsArr {
            let params = ROGoogleTranslateParams(source: "en" , target: "zh", text: word)
            translator.translate(params: params) { (result) in
                DispatchQueue.main.async {
                    numResults += 1
                    translatedArr.append(result)
                    
                    if numResults == wordsArr.count {
                        callback(translatedArr)
                    }
                }
            }
        }
    }
    
    
}
