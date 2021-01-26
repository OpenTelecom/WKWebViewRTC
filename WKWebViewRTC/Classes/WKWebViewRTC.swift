//
//  WKWebViewRTC.swift
//  WKWebViewRTC
//
//  Created by Open Telecom Foundation on 2020/6/30.
//  Copyright © 2020 Open Telecom Foundation. All rights reserved.
//  The MIT License (MIT)
//

import Foundation
import AVFoundation
import WebRTC
import WebKit

public class WKWebViewRTC : NSObject {
	// RTCPeerConnectionFactory single instance.
	var rtcPeerConnectionFactory: RTCPeerConnectionFactory!
	// Single PluginGetUserMedia instance.
	var pluginGetUserMedia: iGetUserMedia!
	// PluginRTCPeerConnection dictionary.
	var pluginRTCPeerConnections: [Int : iRTCPeerConnection]!
	// PluginMediaStream dictionary.
	var pluginMediaStreams: [String : iMediaStream]!
	// PluginMediaStreamTrack dictionary.
	var pluginMediaStreamTracks: [String : iMediaStreamTrack]!
	// PluginMediaStreamRenderer dictionary.
	var pluginMediaStreamRenderers: [Int : iMediaStreamRenderer]!
	// Dispatch queue for serial operations.
	var queue: DispatchQueue!
	// Auto selecting output speaker
	var audioOutputController: iRTCAudioController!
    var webView : WKWebView?
    

	// This is just called if <param name="onload" value="true" /> in plugin.xml.
    public init(wkwebview:WKWebView?, contentController: WKUserContentController?) {
		NSLog("WKWebViewRTC#init()")
        super.init()

		// Make the web view transparent

		pluginMediaStreams = [:]
		pluginMediaStreamTracks = [:]
		pluginMediaStreamRenderers = [:]
		queue = DispatchQueue(label: "wkwebview-iosrtc", attributes: [])
		pluginRTCPeerConnections = [:]

        setWebView(webview: wkwebview)
        
        
        if let path = Bundle(for: type(of: self)).path(forResource: "jsWKWebViewRTC", ofType: "js") {
            if let bindingJS = try? String(contentsOfFile: path, encoding: .utf8) {
                let script = WKUserScript(source: bindingJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
                contentController?.addUserScript(script)
            }
        }
		else {
			NSLog("Failed to add iosrtc script")
			return
		}
        
		// Initialize DTLS stuff.
		RTCInitializeSSL()
		//RTCSetMinDebugLogLevel(RTCLoggingSeverity.warning)

		// Create a RTCPeerConnectionFactory.
		self.initPeerConnectionFactory();

		// Create a PluginGetUserMedia instance.
		self.pluginGetUserMedia = iGetUserMedia(
			rtcPeerConnectionFactory: rtcPeerConnectionFactory
		)

		// Create a PluginRTCAudioController instance.
		self.audioOutputController = iRTCAudioController()
        contentController?.add(self, name: "WKWebViewRTC")
        contentController?.add(self, name: "native_console_log")
	}
    
    func setWebView(webview:WKWebView?)
    {
        self.webView = webview
        self.webView!.isOpaque = false
        self.webView!.backgroundColor = UIColor.clear
        
    }

	private func initPeerConnectionFactory() {
		let encoderFactory = RTCDefaultVideoEncoderFactory()
		let decoderFactory = RTCDefaultVideoDecoderFactory()
		encoderFactory.preferredCodec = getSupportedVideoEncoder(factory: encoderFactory)

		self.rtcPeerConnectionFactory = RTCPeerConnectionFactory(
			encoderFactory: encoderFactory,
			decoderFactory: decoderFactory
		)
	}

	private func getSupportedVideoEncoder(factory: RTCDefaultVideoEncoderFactory) -> RTCVideoCodecInfo {
		let supportedCodecs: [RTCVideoCodecInfo] = RTCDefaultVideoEncoderFactory.supportedCodecs()
		if supportedCodecs.contains(RTCVideoCodecInfo.init(name: kRTCH264CodecName)){
			return RTCVideoCodecInfo.init(name: kRTCH264CodecName)
		} else if supportedCodecs.contains(RTCVideoCodecInfo.init(name: kRTCVp9CodecName)) {
			return RTCVideoCodecInfo.init(name: kRTCVp9CodecName)
		} else {
			return RTCVideoCodecInfo.init(name: kRTCVp8CodecName)
		}
	}

	@objc(onReset) func onReset() {
		NSLog("WKWebViewRTC#onReset() | doing nothing")
		cleanup();
	}

	@objc(onAppTerminate) func onAppTerminate() {
		NSLog("WKWebViewRTC#onAppTerminate() | doing nothing")
		cleanup();
	}

	@objc(new_RTCPeerConnection:) func new_RTCPeerConnection(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#new_RTCPeerConnection()")

		let pcId = command.argument(at: 0) as! Int
		var pcConfig: NSDictionary?
		var pcConstraints: NSDictionary?

		if command.argument(at: 1) != nil {
			pcConfig = command.argument(at: 1) as? NSDictionary
		}

		if command.argument(at: 2) != nil {
			pcConstraints = command.argument(at: 2) as? NSDictionary
		}

		let pluginRTCPeerConnection = iRTCPeerConnection(
			rtcPeerConnectionFactory: self.rtcPeerConnectionFactory,
			pcConfig: pcConfig,
			pcConstraints: pcConstraints,
			eventListener: { (data: NSDictionary) -> Void in
				let result = WkWebviewCmdResult(
                    status: .WkWebviewCmdStatus_OK,
					messageAs: data as? [AnyHashable: Any]
				)

				// Allow more callbacks.
				//result?.setKeepCallbackAs(true);
				self.emit(command.callbackId, result: result)
			},
			eventListenerForAddStream: self.saveMediaStream,
			eventListenerForRemoveStream: self.deleteMediaStream,
			eventListenerForAddTrack: self.saveMediaStreamTrack,
			eventListenerForRemoveTrack: self.deleteMediaStreamTrack
		)

		// Store the pluginRTCPeerConnection into the dictionary.
		self.pluginRTCPeerConnections[pcId] = pluginRTCPeerConnection

		// Run it.
		pluginRTCPeerConnection.run()
	}

	@objc(RTCPeerConnection_createOffer:) func RTCPeerConnection_createOffer(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_createOffer()")

		let pcId = command.argument(at: 0) as! Int
		var options: NSDictionary?

		if command.argument(at: 1) != nil {
			options = command.argument(at: 1) as? NSDictionary
		}

		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_createOffer() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection] in
			pluginRTCPeerConnection?.createOffer(options,
				callback: { (data: NSDictionary) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(
                            status: .WkWebviewCmdStatus_OK,
							messageAs: data as? [AnyHashable: Any]
						)
					)
				},
				errback: { (error: Error) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(status:.WkWebviewCmdStatus_ERROR, messageAs: error.localizedDescription)
					)
				}
			)
		}
	}

	@objc(RTCPeerConnection_createAnswer:) func RTCPeerConnection_createAnswer(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_createAnswer()")

		let pcId = command.argument(at: 0) as! Int
		var options: NSDictionary?

		if command.argument(at: 1) != nil {
			options = command.argument(at: 1) as? NSDictionary
		}

		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_createAnswer() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection] in
			pluginRTCPeerConnection?.createAnswer(options,
				callback: { (data: NSDictionary) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(
                            status: .WkWebviewCmdStatus_OK,
							messageAs: data as? [AnyHashable: Any]
						)
					)
				},
				errback: { (error: Error) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(status:.WkWebviewCmdStatus_ERROR, messageAs: error.localizedDescription)
					)
				}
			)
		}
	}

	@objc(RTCPeerConnection_setLocalDescription:) func RTCPeerConnection_setLocalDescription(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_setLocalDescription()")

		let pcId = command.argument(at: 0) as! Int
		let desc = command.argument(at: 1) as! NSDictionary
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_setLocalDescription() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection] in
			pluginRTCPeerConnection?.setLocalDescription(desc,
				callback: { (data: NSDictionary) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(
                            status: .WkWebviewCmdStatus_OK,
							messageAs: data as? [AnyHashable: Any]
						)
					)
				},
				errback: { (error: Error) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(status:.WkWebviewCmdStatus_ERROR, messageAs: error.localizedDescription)
					)
				}
			)
		}
	}

	@objc(RTCPeerConnection_setRemoteDescription:) func RTCPeerConnection_setRemoteDescription(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_setRemoteDescription()")

		let pcId = command.argument(at: 0) as! Int
		let desc = command.argument(at: 1) as! NSDictionary
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_setRemoteDescription() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection] in
			pluginRTCPeerConnection?.setRemoteDescription(desc,
				callback: { (data: NSDictionary) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(
                            status: .WkWebviewCmdStatus_OK,
							messageAs: data as? [AnyHashable: Any]
						)
					)
				},
				errback: { (error: Error) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(status:.WkWebviewCmdStatus_ERROR, messageAs: error.localizedDescription)
					)
				}
			)
		}
	}

	@objc(RTCPeerConnection_addIceCandidate:) func RTCPeerConnection_addIceCandidate(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_addIceCandidate()")

		let pcId = command.argument(at: 0) as! Int
		let candidate = command.argument(at: 1) as! NSDictionary
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_addIceCandidate() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection] in
			pluginRTCPeerConnection?.addIceCandidate(candidate,
				callback: { (data: NSDictionary) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(
                            status: .WkWebviewCmdStatus_OK,
							messageAs: data as? [AnyHashable: Any]
						)
					)
				},
				errback: { () -> Void in
					self.emit(command.callbackId,
                              result: WkWebviewCmdResult(status: .WkWebviewCmdStatus_ERROR)
					)
				}
			)
		}
	}

	@objc(RTCPeerConnection_addStream:) func RTCPeerConnection_addStream(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_addStream()")

		let pcId = command.argument(at: 0) as! Int
		let streamId = command.argument(at: 1) as! String
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]
		let pluginMediaStream = self.pluginMediaStreams[streamId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_addStream() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		if pluginMediaStream == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_addStream() | ERROR: pluginMediaStream with id=%@ does not exist", String(streamId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection, weak pluginMediaStream] in
			if pluginRTCPeerConnection?.addStream(pluginMediaStream!) == true {
				self.saveMediaStream(pluginMediaStream!)
			}
		}
	}

	@objc(RTCPeerConnection_removeStream:) func RTCPeerConnection_removeStream(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_removeStream()")

		let pcId = command.argument(at: 0) as! Int
		let streamId = command.argument(at: 1) as! String
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]
		let pluginMediaStream = self.pluginMediaStreams[streamId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_removeStream() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		if pluginMediaStream == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_removeStream() | ERROR: pluginMediaStream with id=%@ does not exist", String(streamId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection, weak pluginMediaStream] in
			pluginRTCPeerConnection?.removeStream(pluginMediaStream!)
		}
	}

	@objc(RTCPeerConnection_addTrack:) func RTCPeerConnection_addTrack(_ command: WkWebviewCommand) {

		let pcId = command.argument(at: 0) as! Int
		let trackId = command.argument(at: 1) as! String
		var streamIds : [String] = [];
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]
		let pluginMediaStreamTrack = self.pluginMediaStreamTracks[trackId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_addTrack() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		if command.argument(at: 2) != nil {
			let id = command.argument(at: 2) as! String
			let pluginMediaStream = self.pluginMediaStreams[id]

			if pluginMediaStream == nil {
				NSLog("WKWebViewRTC#RTCPeerConnection_addTrack() | ERROR: pluginMediaStream with id=%@ does not exist", String(id))
				return;
			}

			let streamId = pluginMediaStream!.rtcMediaStream.streamId;
			streamIds.append(streamId)
			self.saveMediaStream(pluginMediaStream!)
		}

		if pluginMediaStreamTrack == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_addTrack() | ERROR: pluginMediaStreamTrack with id=\(trackId) does not exist")
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection, weak pluginMediaStreamTrack] in
			if pluginRTCPeerConnection?.addTrack(pluginMediaStreamTrack!, streamIds) == true {
				self.saveMediaStreamTrack(pluginMediaStreamTrack!)
			}
		}
	}

	@objc(RTCPeerConnection_removeTrack:) func RTCPeerConnection_removeTrack(_ command: WkWebviewCommand) {
		let pcId = command.argument(at: 0) as! Int
		let trackId = command.argument(at: 1) as! String
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]
		let pluginMediaStreamTrack = self.pluginMediaStreamTracks[trackId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_removeTrack() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		if pluginMediaStreamTrack == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_removeTrack() | ERROR: pluginMediaStreamTrack with id=\(trackId) does not exist")
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection, weak pluginMediaStreamTrack] in
			pluginRTCPeerConnection?.removeTrack(pluginMediaStreamTrack!)
			// TODO remove only if not used by other stream
			// self.deleteMediaStreamTrack(pluginMediaStreamTrack!)
		}
	}

	@objc(RTCPeerConnection_createDataChannel:) func RTCPeerConnection_createDataChannel(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_createDataChannel()")

		let pcId = command.argument(at: 0) as! Int
		let dcId = command.argument(at: 1) as! Int
		let label = command.argument(at: 2) as! String
		var options: NSDictionary?

		if command.argument(at: 3) != nil {
			options = command.argument(at: 3) as? NSDictionary
		}

		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_createDataChannel() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection] in
			pluginRTCPeerConnection?.createDataChannel(dcId,
				label: label,
				options: options,
				eventListener: { (data: NSDictionary) -> Void in
					let result = WkWebviewCmdResult(
                        status: .WkWebviewCmdStatus_OK,
						messageAs: data as? [AnyHashable: Any]
					)

					// Allow more callbacks.
					//result!.setKeepCallbackAs(true);
					self.emit(command.callbackId, result: result)
				},
				eventListenerForBinaryMessage: { (data: Data) -> Void in
                    let result = WkWebviewCmdResult(status: .WkWebviewCmdStatus_OK, messageAsArrayBuffer: data)

					// Allow more callbacks.
					//result!.setKeepCallbackAs(true);
					self.emit(command.callbackId, result: result)
				}
			)
		}
	}

	@objc(RTCPeerConnection_getStats:) func RTCPeerConnection_getStats(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_getStats()")

		let pcId = command.argument(at: 0) as! Int
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_getStats() | ERROR: pluginRTCPeerConnection with pcId=\(pcId) does not exist")
			return;
		}

		var pluginMediaStreamTrack: iMediaStreamTrack?

		if command.argument(at: 1) != nil {
			let trackId = command.argument(at: 1) as! String
			pluginMediaStreamTrack = self.pluginMediaStreamTracks[trackId]

			if pluginMediaStreamTrack == nil {
				NSLog("WKWebViewRTC#RTCPeerConnection_getStats() | ERROR: pluginMediaStreamTrack with id=\(trackId) does not exist")
				return;
			}
		}

		self.queue.async { [weak pluginRTCPeerConnection, weak pluginMediaStreamTrack] in
			pluginRTCPeerConnection?.getStats(pluginMediaStreamTrack,
				callback: { (array: [[String:Any]]) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(
                            status: .WkWebviewCmdStatus_OK,
							messageAs: array as [AnyObject]
						)
					)
				},
				errback: { (error: NSError) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(
                            status: .WkWebviewCmdStatus_ERROR,
							messageAs: error.localizedDescription
						)
					)
				}
			)
		}
	}

	@objc(RTCPeerConnection_close:) func RTCPeerConnection_close(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_close()")

		let pcId = command.argument(at: 0) as! Int
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_close() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection] in
			if pluginRTCPeerConnection != nil {
				pluginRTCPeerConnection!.close()
			}

			// Remove the pluginRTCPeerConnection from the dictionary.
			self.pluginRTCPeerConnections[pcId] = nil
		}
	}

	@objc(RTCPeerConnection_RTCDataChannel_setListener:) func RTCPeerConnection_RTCDataChannel_setListener(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_RTCDataChannel_setListener()")

		let pcId = command.argument(at: 0) as! Int
		let dcId = command.argument(at: 1) as! Int
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_RTCDataChannel_setListener() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection] in
			pluginRTCPeerConnection?.RTCDataChannel_setListener(dcId,
				eventListener: { (data: NSDictionary) -> Void in
					let result = WkWebviewCmdResult(
						status:.WkWebviewCmdStatus_OK,
						messageAs: data as? [AnyHashable: Any]
					)

					// Allow more callbacks.
					//result!.setKeepCallbackAs(true);
					self.emit(command.callbackId, result: result)
				},
				eventListenerForBinaryMessage: { (data: Data) -> Void in
					let result = WkWebviewCmdResult(status:.WkWebviewCmdStatus_OK, messageAsArrayBuffer: data)

					// Allow more callbacks.
					//result!.setKeepCallbackAs(true);
					self.emit(command.callbackId, result: result)
				}
			)
		}
	}

	@objc(RTCPeerConnection_RTCDataChannel_sendString:) func RTCPeerConnection_RTCDataChannel_sendString(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_RTCDataChannel_sendString()")

		let pcId = command.argument(at: 0) as! Int
		let dcId = command.argument(at: 1) as! Int
		let data = command.argument(at: 2) as! String
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_RTCDataChannel_sendString() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection] in
			pluginRTCPeerConnection?.RTCDataChannel_sendString(dcId,
				data: data,
				callback: { (data: NSDictionary) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(
							status:.WkWebviewCmdStatus_OK,
							messageAs: data as? [AnyHashable: Any]
						)
					)
				}
			)
		}
	}

	@objc(RTCPeerConnection_RTCDataChannel_sendBinary:) func RTCPeerConnection_RTCDataChannel_sendBinary(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_RTCDataChannel_sendBinary()")

		let pcId = command.argument(at: 0) as! Int
		let dcId = command.argument(at: 1) as! Int
		let data = command.argument(at: 2) as! Data
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_RTCDataChannel_sendBinary() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection] in
			pluginRTCPeerConnection?.RTCDataChannel_sendBinary(dcId,
				data: data,
				callback: { (data: NSDictionary) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(
							status:.WkWebviewCmdStatus_OK,
							messageAs: data as? [AnyHashable: Any]
						)
					)
				}
			)
		}
	}

	@objc(RTCPeerConnection_RTCDataChannel_close:) func RTCPeerConnection_RTCDataChannel_close(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_RTCDataChannel_close()")

		let pcId = command.argument(at: 0) as! Int
		let dcId = command.argument(at: 1) as! Int
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_RTCDataChannel_close() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection] in
			pluginRTCPeerConnection?.RTCDataChannel_close(dcId)
		}
	}

	@objc(RTCPeerConnection_createDTMFSender:) func RTCPeerConnection_createDTMFSender(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_createDTMFSender()")

		let pcId = command.argument(at: 0) as! Int
		let dsId = command.argument(at: 1) as! Int
		let trackId = command.argument(at: 2) as! String
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]
		let pluginMediaStreamTrack = self.pluginMediaStreamTracks[trackId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_createDTMFSender() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		if pluginMediaStreamTrack == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_createDTMFSender() | ERROR: pluginMediaStreamTrack with id=%@ does not exist", String(trackId))
			return;
		}


		self.queue.async { [weak pluginRTCPeerConnection] in
			pluginRTCPeerConnection?.createDTMFSender(dsId,
				track: pluginMediaStreamTrack!,
				eventListener: { (data: NSDictionary) -> Void in
					let result = WkWebviewCmdResult(
						status:.WkWebviewCmdStatus_OK,
						messageAs: data as? [AnyHashable: Any]
					)

					// Allow more callbacks.
					//result!.setKeepCallbackAs(true);
					self.emit(command.callbackId, result: result)
				}
			)
		}
	}

	@objc(RTCPeerConnection_RTCDTMFSender_insertDTMF:) func RTCPeerConnection_RTCDTMFSender_insertDTMF(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#RTCPeerConnection_RTCDTMFSender_insertDTMF()")

		let pcId = command.argument(at: 0) as! Int
		let dsId = command.argument(at: 1) as! Int
		let tones = command.argument(at: 2) as! String
		let duration = command.argument(at: 3) as! Double
		let interToneGap = command.argument(at: 4) as! Double
		let pluginRTCPeerConnection = self.pluginRTCPeerConnections[pcId]

		if pluginRTCPeerConnection == nil {
			NSLog("WKWebViewRTC#RTCPeerConnection_RTCDTMFSender_insertDTMF() | ERROR: pluginRTCPeerConnection with pcId=%@ does not exist", String(pcId))
			return;
		}

		self.queue.async { [weak pluginRTCPeerConnection] in
			pluginRTCPeerConnection?.RTCDTMFSender_insertDTMF(dsId,
				tones: tones,
				duration: duration,
				interToneGap: interToneGap
			)
		}
	}

	@objc(MediaStream_init:) func MediaStream_init(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStream_init()")

		let streamId = command.argument(at: 0) as! String

		if self.pluginMediaStreams[streamId] == nil {
			let rtcMediaStream : RTCMediaStream = self.rtcPeerConnectionFactory.mediaStream(withStreamId: streamId)
			let pluginMediaStream = iMediaStream(rtcMediaStream: rtcMediaStream, streamId: streamId)
			pluginMediaStream.run()

			self.saveMediaStream(pluginMediaStream)
		} else {
			NSLog("WKWebViewRTC#MediaStream_init() | ERROR: pluginMediaStream with id=%@ already exist", String(streamId))
		}
	}

	@objc(MediaStream_setListener:) func MediaStream_setListener(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStream_setListener()")

		let id = command.argument(at: 0) as! String
		let pluginMediaStream = self.pluginMediaStreams[id]

		if pluginMediaStream == nil {
			NSLog("WKWebViewRTC#MediaStream_setListener() | ERROR: pluginMediaStream with id=%@ does not exist", String(id))
			return;
		}

		self.queue.async { [weak pluginMediaStream] in
			// Set the eventListener.
			pluginMediaStream?.setListener(
				{ (data: NSDictionary) -> Void in
					let result = WkWebviewCmdResult(
						status:.WkWebviewCmdStatus_OK,
						messageAs: data as? [AnyHashable: Any]
					)

					// Allow more callbacks.
					//result!.setKeepCallbackAs(true);
					self.emit(command.callbackId, result: result)
				},
				eventListenerForAddTrack: self.saveMediaStreamTrack,
				eventListenerForRemoveTrack: self.deleteMediaStreamTrack
			)
		}
	}

	@objc(MediaStream_addTrack:) func MediaStream_addTrack(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStream_addTrack()")

		let id = command.argument(at: 0) as! String
		let trackId = command.argument(at: 1) as! String
		let pluginMediaStream = self.pluginMediaStreams[id]
		let pluginMediaStreamTrack = self.pluginMediaStreamTracks[trackId]

		if pluginMediaStream == nil {
			NSLog("WKWebViewRTC#MediaStream_addTrack() | ERROR: pluginMediaStream with id=%@ does not exist", String(id))
			return
		}

		if pluginMediaStreamTrack == nil {
			NSLog("WKWebViewRTC#MediaStream_addTrack() | ERROR: pluginMediaStreamTrack with id=%@ does not exist", String(trackId))
			return;
		}

		self.queue.async { [weak pluginMediaStream, weak pluginMediaStreamTrack] in
			pluginMediaStream?.addTrack(pluginMediaStreamTrack!)
		}
	}

	@objc(MediaStream_removeTrack:) func MediaStream_removeTrack(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStream_removeTrack()")

		let id = command.argument(at: 0) as! String
		let trackId = command.argument(at: 1) as! String
		let pluginMediaStream = self.pluginMediaStreams[id]
		let pluginMediaStreamTrack = self.pluginMediaStreamTracks[trackId]

		if pluginMediaStream == nil {
			NSLog("WKWebViewRTC#MediaStream_removeTrack() | ERROR: pluginMediaStream with id=%@ does not exist", String(id))
			return
		}

		if pluginMediaStreamTrack == nil {
			NSLog("WKWebViewRTC#MediaStream_removeTrack() | ERROR: pluginMediaStreamTrack with id=%@ does not exist", String(trackId))
			return;
		}

		self.queue.async { [weak pluginMediaStream, weak pluginMediaStreamTrack] in
			pluginMediaStream?.removeTrack(pluginMediaStreamTrack!)

			// TODO only stop if no more pluginMediaStream attached only
			// currently pluginMediaStreamTrack can be attached to more than one pluginMediaStream
			// use track.stop() or stream.stop() to stop tracks
			//pluginMediaStreamTrack?.stop()
		}
	}

	@objc(MediaStream_release:) func MediaStream_release(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStream_release()")

		let id = command.argument(at: 0) as! String
		let pluginMediaStream = self.pluginMediaStreams[id]

		if pluginMediaStream == nil {
			NSLog("WKWebViewRTC#MediaStream_release() | ERROR: pluginMediaStream with id=%@ does not exist", String(id))
			return;
		}

		self.pluginMediaStreams[id] = nil
	}

	@objc(MediaStreamTrack_clone:) func MediaStreamTrack_clone(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStreamTrack_clone()")

		let existingTrackId = command.argument(at: 0) as! String
		let newTrackId = command.argument(at: 1) as! String
		let pluginMediaStreamTrack = self.pluginMediaStreamTracks[existingTrackId]

		if pluginMediaStreamTrack == nil {
			NSLog("WKWebViewRTC#MediaStreamTrack_clone() | ERROR: pluginMediaStreamTrack with id=%@ does not exist", String(existingTrackId))
			return;
		}

		if self.pluginMediaStreams[newTrackId] == nil {
			var rtcMediaStreamTrack = self.pluginMediaStreamTracks[existingTrackId]!.rtcMediaStreamTrack;
			// twilio uses the sdp local description to map the track ids to the media id.
			// if the original rtcMediaStreamTrack is not cloned, the rtcPeerConnection 
			// will not add the track and as such will not be found by Twilio. 
			// it is unable to do the mapping and find track and thus
			// will not publish the local track.
			if pluginMediaStreamTrack?.kind == "video" {
				if let rtcVideoTrack = rtcMediaStreamTrack as? RTCVideoTrack{
					NSLog("WKWebViewRTC#MediaStreamTrack_clone() cloning video source");
					rtcMediaStreamTrack = self.rtcPeerConnectionFactory.videoTrack(with: rtcVideoTrack.source, trackId: newTrackId);
				}
			} else if pluginMediaStreamTrack?.kind == "audio" {
				if let rtcAudioTrack = rtcMediaStreamTrack as? RTCAudioTrack{
					NSLog("WKWebViewRTC#MediaStreamTrack_clone() cloning audio source");
					rtcMediaStreamTrack = self.rtcPeerConnectionFactory.audioTrack(with: rtcAudioTrack.source, trackId: newTrackId);
				}
			}
			let newPluginMediaStreamTrack = iMediaStreamTrack(rtcMediaStreamTrack: rtcMediaStreamTrack, trackId: newTrackId)

			self.saveMediaStreamTrack(newPluginMediaStreamTrack)
		} else {
			NSLog("WKWebViewRTC#MediaStreamTrack_clone() | ERROR: pluginMediaStreamTrack with id=%@ already exist", String(newTrackId))
		}
	}

	@objc(MediaStreamTrack_setListener:) func MediaStreamTrack_setListener(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStreamTrack_setListener()")

		let id = command.argument(at: 0) as! String
		let pluginMediaStreamTrack = self.pluginMediaStreamTracks[id]

		if pluginMediaStreamTrack == nil {
			NSLog("WKWebViewRTC#MediaStreamTrack_setListener() | ERROR: pluginMediaStreamTrack with id=%@ does not exist", String(id))
			return;
		}

		self.queue.async { [weak pluginMediaStreamTrack] in
			// Set the eventListener.
			pluginMediaStreamTrack?.setListener(
				{ (data: NSDictionary) -> Void in
					let result = WkWebviewCmdResult(
						status:.WkWebviewCmdStatus_OK,
						messageAs: data as? [AnyHashable: Any]
					)

					// Allow more callbacks.
					//result!.setKeepCallbackAs(true);
					self.emit(command.callbackId, result: result)
				},
				eventListenerForEnded: { () -> Void in
					// Remove the track from the container.
					self.deleteMediaStreamTrack(pluginMediaStreamTrack!);
				}
			)
		}
	}

	@objc(MediaStreamTrack_setEnabled:) func MediaStreamTrack_setEnabled(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStreamTrack_setEnabled()")

		let id = command.argument(at: 0) as! String
		let value = command.argument(at: 1) as! Bool
		let pluginMediaStreamTrack = self.pluginMediaStreamTracks[id]

		if pluginMediaStreamTrack == nil {
			NSLog("WKWebViewRTC#MediaStreamTrack_setEnabled() | ERROR: pluginMediaStreamTrack with id=%@ does not exist", String(id))
			return;
		}

		self.queue.async {[weak pluginMediaStreamTrack] in
			pluginMediaStreamTrack?.setEnabled(value)
		}
	}

	@objc(MediaStreamTrack_stop:) func MediaStreamTrack_stop(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStreamTrack_stop()")

		let id = command.argument(at: 0) as! String
		let pluginMediaStreamTrack = self.pluginMediaStreamTracks[id]

		if pluginMediaStreamTrack == nil {
			NSLog("WKWebViewRTC#MediaStreamTrack_stop() | ERROR: pluginMediaStreamTrack with id=%@ does not exist", String(id))
			return;
		}

		self.queue.async { [weak pluginMediaStreamTrack] in
			pluginMediaStreamTrack?.stop()
		}
	}

	@objc(new_MediaStreamRenderer:) func new_MediaStreamRenderer(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#new_MediaStreamRenderer()")

		let id = command.argument(at: 0) as! Int

		let pluginMediaStreamRenderer = iMediaStreamRenderer(
			webView: self.webView!,
			eventListener: { (data: NSDictionary) -> Void in
				let result = WkWebviewCmdResult(
					status:.WkWebviewCmdStatus_OK,
					messageAs: data as? [AnyHashable: Any]
				)

				// Allow more callbacks.
				//result?.setKeepCallbackAs(true);
				self.emit(command.callbackId, result: result)
			}
		)

		// Store into the dictionary.
		self.pluginMediaStreamRenderers[id] = pluginMediaStreamRenderer

		// Run it.
		pluginMediaStreamRenderer.run()
	}

	@objc(MediaStreamRenderer_render:) func MediaStreamRenderer_render(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStreamRenderer_render()")

		let id = command.argument(at: 0) as! Int
		let streamId = command.argument(at: 1) as! String
		let pluginMediaStreamRenderer = self.pluginMediaStreamRenderers[id]
		let pluginMediaStream = self.pluginMediaStreams[streamId]

		if pluginMediaStreamRenderer == nil {
			NSLog("WKWebViewRTC#MediaStreamRenderer_render() | ERROR: pluginMediaStreamRenderer with id=%@ does not exist", String(id))
			return
		}

		if pluginMediaStream == nil {
			NSLog("WKWebViewRTC#MediaStreamRenderer_render() | ERROR: pluginMediaStream with id=%@ does not exist", String(streamId))
			return;
		}

		pluginMediaStreamRenderer!.render(pluginMediaStream!)
	}

	@objc(MediaStreamRenderer_mediaStreamChanged:) func MediaStreamRenderer_mediaStreamChanged(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStreamRenderer_mediaStreamChanged()")

		let id = command.argument(at: 0) as! Int
		let pluginMediaStreamRenderer = self.pluginMediaStreamRenderers[id]

		if pluginMediaStreamRenderer == nil {
			NSLog("WKWebViewRTC#MediaStreamRenderer_mediaStreamChanged() | ERROR: pluginMediaStreamRenderer with id=%@ does not exist", String(id))
			return;
		}

		pluginMediaStreamRenderer!.mediaStreamChanged()
	}

	@objc(MediaStreamRenderer_refresh:) func MediaStreamRenderer_refresh(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStreamRenderer_refresh()")

		let id = command.argument(at: 0) as! Int
		let data = command.argument(at: 1) as! NSDictionary
		let pluginMediaStreamRenderer = self.pluginMediaStreamRenderers[id]

		if pluginMediaStreamRenderer == nil {
			NSLog("WKWebViewRTC#MediaStreamRenderer_refresh() | ERROR: pluginMediaStreamRenderer with id=%@ does not exist", String(id))
			return;
		}

		pluginMediaStreamRenderer!.refresh(data)
	}

	@objc(MediaStreamRenderer_save:) func MediaStreamRenderer_save(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStreamRenderer_save()")

		let id = command.argument(at: 0) as! Int
		let pluginMediaStreamRenderer = self.pluginMediaStreamRenderers[id]

		if pluginMediaStreamRenderer == nil {
			NSLog("WKWebViewRTC#MediaStreamRenderer_save() | ERROR: pluginMediaStreamRenderer with id=%@ does not exist", String(id))
			return;
		}

		// Perform the task on a background queue.
		DispatchQueue.global().async {
			pluginMediaStreamRenderer!.save(
				callback: { (data: String) -> Void in
					DispatchQueue.main.async {
						self.emit(command.callbackId,
							result: WkWebviewCmdResult(
								status:.WkWebviewCmdStatus_OK,
								messageAs: data
							)
						)
					}
				},
				errback: { (error: String) -> Void in
					self.emit(command.callbackId,
                              result: WkWebviewCmdResult(status: .WkWebviewCmdStatus_ERROR, messageAs: error)
					)
				}
			)
		}
	}

	@objc(MediaStreamRenderer_close:) func MediaStreamRenderer_close(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#MediaStreamRenderer_close()")

		let id = command.argument(at: 0) as! Int
		let pluginMediaStreamRenderer = self.pluginMediaStreamRenderers[id]

		if pluginMediaStreamRenderer == nil {
			NSLog("WKWebViewRTC#MediaStreamRenderer_close() | ERROR: pluginMediaStreamRenderer with id=%@ does not exist", String(id))
			return
		}

		pluginMediaStreamRenderer!.close()

		// Remove from the dictionary.
		self.pluginMediaStreamRenderers[id] = nil
	}

	@objc(getUserMedia:) func getUserMedia(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#getUserMedia()")

		let constraints = command.argument(at: 0) as! NSDictionary

		self.pluginGetUserMedia.call(constraints,
			callback: { (data: NSDictionary) -> Void in
				self.emit(command.callbackId,
					result: WkWebviewCmdResult(
						status:.WkWebviewCmdStatus_OK,
						messageAs: data as? [AnyHashable: Any]
					)
				)
			},
			errback: { (error: String) -> Void in
				self.emit(command.callbackId,
					result: WkWebviewCmdResult(status:.WkWebviewCmdStatus_ERROR, messageAs: error)
				)
			},
			eventListenerForNewStream: self.saveMediaStream
		)
	}

	@objc(enumerateDevices:) func enumerateDevices(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#enumerateDevices()")

		self.queue.async {
			iEnumerateDevices.call(
				{ (data: NSDictionary) -> Void in
					self.emit(command.callbackId,
						result: WkWebviewCmdResult(
							status:.WkWebviewCmdStatus_OK,
							messageAs: data as? [AnyHashable: Any]
						)
					)
				}
			)
		}
	}

	@objc(RTCRequestPermission:) func RTCRequestPermission(_ command: WkWebviewCommand) {
		DispatchQueue.main.async {
			let audioRequested: Bool = CBool(command.arguments[0] as! Bool)
			let videoRequested: Bool = CBool(command.arguments[1] as! Bool)
			var status: Bool = true

			if videoRequested == true {
				switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
				case AVAuthorizationStatus.notDetermined:
					NSLog("PluginGetUserMedia#call() | video authorization: not determined")
				case AVAuthorizationStatus.authorized:
					NSLog("PluginGetUserMedia#call() | video authorization: authorized")
				case AVAuthorizationStatus.denied:

					NSLog("PluginGetUserMedia#call() | video authorization: denied")
					status = false
				case AVAuthorizationStatus.restricted:
					NSLog("PluginGetUserMedia#call() | video authorization: restricted")
					status = false
				}
			}

			if audioRequested == true {
				switch AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) {
				case AVAuthorizationStatus.notDetermined:
					NSLog("PluginGetUserMedia#call() | audio authorization: not determined")
				case AVAuthorizationStatus.authorized:
					NSLog("PluginGetUserMedia#call() | audio authorization: authorized")
				case AVAuthorizationStatus.denied:
					NSLog("PluginGetUserMedia#call() | audio authorization: denied")
					status = false
				case AVAuthorizationStatus.restricted:
					NSLog("PluginGetUserMedia#call() | audio authorization: restricted")
					status = false
				}
			}

			if (status) {
				self.emit(command.callbackId,result: WkWebviewCmdResult(status:.WkWebviewCmdStatus_OK))
			} else {
				self.emit(command.callbackId,result: WkWebviewCmdResult(status:.WkWebviewCmdStatus_ERROR))
			}
		}
	}

	@objc(initAudioDevices:) func initAudioDevices(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#initAudioDevices()")

		iRTCAudioController.initAudioDevices()
	}

    @objc(RTCTurnOnSpeaker:) func RTCTurnOnSpeaker(_ command: WkWebviewCommand) {
		DispatchQueue.main.async {
			let isTurnOn: Bool = CBool(command.arguments[0] as! Bool)
			iRTCAudioController.setOutputSpeakerIfNeed(enabled: isTurnOn)
			self.emit(command.callbackId, result: WkWebviewCmdResult(status:.WkWebviewCmdStatus_OK))
		}
	}

	@objc(selectAudioOutputEarpiece:) func selectAudioOutputEarpiece(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#selectAudioOutputEarpiece()")

		iRTCAudioController.selectAudioOutputEarpiece()
	}

	@objc(selectAudioOutputSpeaker:) func selectAudioOutputSpeaker(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#selectAudioOutputSpeaker()")

		iRTCAudioController.selectAudioOutputSpeaker()
	}

	@objc(dump:) func dump(_ command: WkWebviewCommand) {
		NSLog("WKWebViewRTC#dump()")

		for (id, _) in self.pluginRTCPeerConnections {
			NSLog("- PluginRTCPeerConnection [id:%@]", String(id))
		}

		for (_, pluginMediaStream) in self.pluginMediaStreams {
			NSLog("- PluginMediaStream %@", String(pluginMediaStream.rtcMediaStream.description))
		}

		for (id, pluginMediaStreamTrack) in self.pluginMediaStreamTracks {
			NSLog("- PluginMediaStreamTrack [id:%@, kind:%@]", String(id), String(pluginMediaStreamTrack.kind))
		}

		for (id, _) in self.pluginMediaStreamRenderers {
			NSLog("- PluginMediaStreamRenderer [id:%@]", String(id))
		}
	}

	/**
	 * Private API.
	 */

	fileprivate func emit(_ callbackId: String, result: WkWebviewCmdResult) {
		DispatchQueue.main.async {
            let status = result.status.rawValue
            let argumentsAsJSON = result.argumentAsJSON()
            let js = "jsWKWebViewRTC.nativeCallback('\(callbackId)',\(status),\(argumentsAsJSON))"
            self.webView?.evaluateJavaScript(js, completionHandler: nil)
		}
	}

	fileprivate func saveMediaStream(_ pluginMediaStream: iMediaStream) {
		if self.pluginMediaStreams[pluginMediaStream.id] == nil {
			self.pluginMediaStreams[pluginMediaStream.id] = pluginMediaStream
		} else {
			NSLog("- PluginMediaStreams already exist [id:%@]", String(pluginMediaStream.id))
			return;
		}

		// Store its PluginMediaStreamTracks' into the dictionary.
		for (_, pluginMediaStreamTrack) in pluginMediaStream.audioTracks {
			saveMediaStreamTrack(pluginMediaStreamTrack);
		}

		for (_, pluginMediaStreamTrack) in pluginMediaStream.videoTracks {
			saveMediaStreamTrack(pluginMediaStreamTrack);
		}
	}

	fileprivate func deleteMediaStream(_ pluginMediaStream: iMediaStream) {
		if (self.pluginMediaStreams[pluginMediaStream.id] != nil) {
			self.pluginMediaStreams[pluginMediaStream.id] = nil
			
			// deinit should call stop by itself
			//pluginMediaStream.stop();
		}
	}

	fileprivate func saveMediaStreamTrack(_ pluginMediaStreamTrack: iMediaStreamTrack) {
		if self.pluginMediaStreamTracks[pluginMediaStreamTrack.id] == nil {
			self.pluginMediaStreamTracks[pluginMediaStreamTrack.id] = pluginMediaStreamTrack
		}
	}

	fileprivate func deleteMediaStreamTrack(_ pluginMediaStreamTrack: iMediaStreamTrack) {
		if (self.pluginMediaStreamTracks[pluginMediaStreamTrack.id] != nil) {
			self.pluginMediaStreamTracks[pluginMediaStreamTrack.id] = nil
			
			// deinit should call stop by itself
			//pluginMediaStreamTrack.stop();
		}
	}
    
	fileprivate func cleanup() {

		// Close all RTCPeerConnections
		for (pcId, pluginRTCPeerConnection) in self.pluginRTCPeerConnections {
			pluginRTCPeerConnection.close()
			self.pluginRTCPeerConnections[pcId] = nil;
		}

		// Close all StreamRenderers
		for (id, pluginMediaStreamRenderer) in self.pluginMediaStreamRenderers {
			pluginMediaStreamRenderer.close()
			self.pluginMediaStreamRenderers[id] = nil;
		}

		// Close All MediaStream
		for (streamId, pluginMediaStream) in self.pluginMediaStreams {
			// Store its PluginMediaStreamTracks' into the dictionary.
			for (trackId, pluginMediaStreamTrack) in pluginMediaStream.audioTracks {
				pluginMediaStream.removeTrack(pluginMediaStreamTrack);
				deleteMediaStreamTrack(pluginMediaStreamTrack);
			}

			for (trackId, pluginMediaStreamTrack) in pluginMediaStream.videoTracks {
				pluginMediaStream.removeTrack(pluginMediaStreamTrack);
				deleteMediaStreamTrack(pluginMediaStreamTrack);
			}

			deleteMediaStream(pluginMediaStream);
		}

		// Close All MediaStreamTracks without MediaStream
		for (trackId, pluginMediaStreamTrack) in self.pluginMediaStreamTracks {
			deleteMediaStreamTrack(pluginMediaStreamTrack);
		}
	}
	
    func native_console_log(didReceive message:WKScriptMessage)
    {
        print("console.log: \(message.body)")
    }
}

extension WKWebViewRTC : WKScriptMessageHandler {
	public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("WKWebViewRTC#userContentController(). name=\(message.name)")
        if (message.name == "native_console_log")
        {
            native_console_log(didReceive: message)
        }
        if (message.name == "WKWebViewRTC")
        {
            let jsonString = message.body as! String
            guard let jsonData = jsonString.data(using: String.Encoding.utf8)  else {return}
            
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: [])
            if let anyArray = jsonObject as? [Any] {
                let cmd = WkWebviewCommand(commandFromJson: anyArray)
                let methodString = cmd.methodName + ":"
                let method = Selector(methodString)
                if responds(to: method) {
                    perform(method, with: cmd)
                }
                else
                {
                    print("There is no selector with \(methodString)")
                }
            }
            else{
                print("error json array")
            }
        }
    }
}
