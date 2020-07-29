//
//  WkWebviewCommand.swift
//  WKWebViewRTC
//
//  Created by Open Telecom Foundation on 2020/6/30.
//  Copyright © 2020 Open Telecom Foundation. All rights reserved.
//  The MIT License (MIT)
//

import Foundation

class WkWebviewCommand : NSObject {
    var callbackId : String = ""
    var className : String = ""
    var methodName : String = ""
    var arguments :   [Any] = []
    
    init(commandFromJson:[Any])
    {
        super.init()
        let count = commandFromJson.count
        if count < 4 {
            print("argument is less")
            return
        }
        
        callbackId = commandFromJson[0] as! String
        className = commandFromJson[1] as! String
        methodName = commandFromJson[2] as! String
        arguments = commandFromJson[3] as! [Any]

    }
    
    func argument(at :UInt) -> Any?{
        let count = arguments.count
        if count > at {
            let arg = arguments[Int(at)]
            if arg is NSNull
            {
                return nil
            }
            else {
                return arguments[Int(at)]
            }
        }
        return nil
        
    }

}
