/*
* cordova-plugin-iosrtc v6.0.17
* Cordova iOS plugin exposing the ̶f̶u̶l̶l̶ WebRTC W3C JavaScript APIs.
* Copyright 2015-2017 eFace2Face, Inc. (https://eface2face.com)
* Copyright 2015-2019 BasqueVoIPMafia (https://github.com/BasqueVoIPMafia)
* Copyright 2019 Cordova-RTC (https://github.com/cordova-rtc)
* The MIT License (MIT)
*/

import Foundation
import AVFoundation
import WebRTC

class iGetUserMedia {

	var rtcPeerConnectionFactory: RTCPeerConnectionFactory

	init(rtcPeerConnectionFactory: RTCPeerConnectionFactory) {
		NSLog("iGetUserMedia#init()")
		self.rtcPeerConnectionFactory = rtcPeerConnectionFactory
	}

	deinit {
		NSLog("iGetUserMedia#deinit()")
	}

	func call(
		_ constraints: NSDictionary,
		callback: (_ data: NSDictionary) -> Void,
		errback: (_ error: String) -> Void,
		eventListenerForNewStream: (_ pluginMediaStream: iMediaStream) -> Void
	) {

		NSLog("iGetUserMedia#call()")

		var videoRequested: Bool = false
		var audioRequested: Bool = false

		if (constraints.object(forKey: "video") != nil) {
			videoRequested = true
		}
		
		if constraints.object(forKey: "audio") != nil {
			audioRequested = true
		}

		var rtcMediaStream: RTCMediaStream
		var pluginMediaStream: iMediaStream?
		var rtcAudioTrack: RTCAudioTrack?
		var rtcVideoTrack: RTCVideoTrack?
		var rtcVideoSource: RTCVideoSource?

		if videoRequested == true {
			switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
			case AVAuthorizationStatus.notDetermined:
				NSLog("iGetUserMedia#call() | video authorization: not determined")
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        NSLog("iGetUserMedia#call() | video authorization: authorized")
                    }
                }
			case AVAuthorizationStatus.authorized:
				NSLog("iGetUserMedia#call() | video authorization: authorized")
			case AVAuthorizationStatus.denied:
				NSLog("iGetUserMedia#call() | video authorization: denied")
				errback("video denied")
				return
			case AVAuthorizationStatus.restricted:
				NSLog("iGetUserMedia#call() | video authorization: restricted")
				errback("video restricted")
				return
			}
		}

		if audioRequested == true {
			switch AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) {
			case AVAuthorizationStatus.notDetermined:
				NSLog("iGetUserMedia#call() | audio authorization: not determined")
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    if granted {
                        NSLog("iGetUserMedia#call() | audio authorization: authorized")
                    }
                }
			case AVAuthorizationStatus.authorized:
				NSLog("iGetUserMedia#call() | audio authorization: authorized")
			case AVAuthorizationStatus.denied:
				NSLog("iGetUserMedia#call() | audio authorization: denied")
				errback("audio denied")
				return
			case AVAuthorizationStatus.restricted:
				NSLog("iGetUserMedia#call() | audio authorization: restricted")
				errback("audio restricted")
				return
			}
		}

		rtcMediaStream = self.rtcPeerConnectionFactory.mediaStream(withStreamId: UUID().uuidString)

		if videoRequested {
			
			NSLog("iGetUserMedia#call() | video requested")

			rtcVideoSource = self.rtcPeerConnectionFactory.videoSource()

			rtcVideoTrack = self.rtcPeerConnectionFactory.videoTrack(with: rtcVideoSource!, trackId: UUID().uuidString)
			
			// Handle legacy plugin instance or video: true
			var videoConstraints : NSDictionary = [:];
			if (!(constraints.object(forKey: "video") is Bool)) {
			   videoConstraints = constraints.object(forKey: "video") as! NSDictionary
			}

			NSLog("iGetUserMedia#call() | chosen video constraints: %@", videoConstraints)

// Ignore Simulator cause does not support Camera
#if !targetEnvironment(simulator)
			let videoCapturer: RTCCameraVideoCapturer = RTCCameraVideoCapturer(delegate: rtcVideoSource!)
			let videoCaptureController: iRTCVideoCaptureController = iRTCVideoCaptureController(capturer: videoCapturer)
			rtcVideoTrack!.videoCaptureController = videoCaptureController
			
			let constraintsSatisfied = videoCaptureController.setConstraints(constraints: videoConstraints)
			if (!constraintsSatisfied) {
				errback("constraints not satisfied")
				return
			}
			
			let captureStarted = videoCaptureController.startCapture()
			if (!captureStarted) {
				errback("constraints failed")
				return
			}
#endif

			// If videoSource state is "ended" it means that constraints were not satisfied so
			// invoke the given errback.
			if (rtcVideoSource!.state == RTCSourceState.ended) {
				NSLog("iGetUserMedia() | rtcVideoSource.state is 'ended', constraints not satisfied")

				errback("constraints not satisfied")
				return
			}

			if let device = rtcVideoTrack!.videoCaptureController?.device {
				rtcVideoTrack!.capabilities["deviceId"] = device.uniqueID
			}

			rtcMediaStream.addVideoTrack(rtcVideoTrack!)
		}
		
		if audioRequested == true {
			
			NSLog("iGetUserMedia#call() | audio requested")
			
			// Handle legacy plugin instance or audio: true
			var audioConstraints : NSDictionary = [:];
			if (!(constraints.object(forKey: "audio") is Bool)) {
			   audioConstraints = constraints.object(forKey: "audio") as! NSDictionary
			}
			
			NSLog("iGetUserMedia#call() | chosen audio constraints: %@", audioConstraints)
			
			
			var audioDeviceId = audioConstraints.object(forKey: "deviceId") as? String
			if(audioDeviceId == nil && audioConstraints.object(forKey: "deviceId") != nil){
				let audioId = audioConstraints.object(forKey: "deviceId") as! NSDictionary
				audioDeviceId = audioId.object(forKey: "exact") as? String
				if(audioDeviceId == nil){
					audioDeviceId = audioId.object(forKey: "ideal") as? String
				}
			}

			rtcAudioTrack = self.rtcPeerConnectionFactory.audioTrack(withTrackId: UUID().uuidString)
			rtcMediaStream.addAudioTrack(rtcAudioTrack!)

			if audioDeviceId == "default" {
				audioDeviceId = "Built-In Microphone"
			}
			
			if (audioDeviceId != nil) {
				iRTCAudioController.saveInputAudioDevice(inputDeviceUID: audioDeviceId!)
			}
		}

		pluginMediaStream = iMediaStream(rtcMediaStream: rtcMediaStream)
		pluginMediaStream!.run()

		// Let the plugin store it in its dictionary.
		eventListenerForNewStream(pluginMediaStream!)

		callback([
			"stream": pluginMediaStream!.getJSON()
		])
	}
}
