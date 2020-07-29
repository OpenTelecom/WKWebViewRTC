//
//  IOSExec.js
//  WKWebViewRTC
//
//  Created by Open Telecom Foundation on 2020/6/30.
//  Copyright © 2020 Open Telecom Foundation. All rights reserved.
//  The MIT License (MIT)
//

module.exports = execNative;
module.exports.execNative = execNative;
module.exports.nativeCallback = nativeCallback;

var exec_queue = {
    callbackId : Math.floor(Math.random() * 2000000),
    callbacks: {}
};

function execNative(successCallback, failCallback, service, action, actionArgs)
{
    if (window.webkit && window.webkit.messageHandlers)
    {
        if (window.webkit.messageHandlers[service])
        {
            var callbackId = service + exec_queue.callbackId++;
            if (successCallback || failCallback)
            {
                exec_queue.callbacks[callbackId] = {success: successCallback, fail:failCallback};
            }
            command = [callbackId, service, action, actionArgs]
            window.webkit.messageHandlers[service].postMessage(JSON.stringify(command))
        }
    }
}

function nativeCallback(callbackId, status, argumentsAsJson)
{
    try {
        var callback = exec_queue.callbacks[callbackId];
        if (callback)
        {
            if (status == 1 && callback.success)
            {
                callback.success.apply(null, argumentsAsJson);
            }
            else if (status == 0 && callback.fail)
            {
                callback.fail.apply(null, argumentsAsJson);
            }
            //delete exec_queue.callbacks[callbackId];
        }
    }
    catch (err){
        var msg = "Error in callbackId " + callbackId + " : " + err;
        console.log(msg)
    }
}
