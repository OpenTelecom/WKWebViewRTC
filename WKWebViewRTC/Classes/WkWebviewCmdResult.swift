//
//  WkWebviewCmdResult.swift
//  WKWebViewRTC
//
//  Created by Open Telecom Foundation on 2020/6/30.
//  Copyright © 2020 Open Telecom Foundation. All rights reserved.
//  The MIT License (MIT)
//

import Foundation

enum WkWebviewCmdStatus : UInt {
    case WkWebviewCmdStatus_NO_RESULT = 0
    case WkWebviewCmdStatus_OK = 1
    case WkWebviewCmdStatus_ERROR = 2
}

class WkWebviewCmdResult {
    var status : WkWebviewCmdStatus
    var message : Any?
    init(status: WkWebviewCmdStatus) {
        self.status = status
        message = nil
    }
    init(status: WkWebviewCmdStatus, messageAs : Any?) {
        self.status = status
        message = messageAs
    }
    init(status: WkWebviewCmdStatus, messageAsArrayBuffer : Data) {
        self.status = status
        message = messageFromArrayBuffer(data: messageAsArrayBuffer)
        
    }
    func messageFromArrayBuffer(data: Data) -> Any
    {
        return ["Type" : "ArrayBuffer",
                "Data" : data.base64EncodedString()]
    }
    func argumentAsJSON() -> String
    {
        var argInArray : NSArray
        if let arg = self.message {
            argInArray = NSArray(objects: arg)
        }
        else{
            argInArray = NSArray(objects: NSNull())
        }
        if let data = try? JSONSerialization.data(withJSONObject: argInArray, options: []) {
            guard let argJSON =  String(data: data, encoding: .utf8) else {return ""}
            return argJSON
        }
        return ""
    }
}
