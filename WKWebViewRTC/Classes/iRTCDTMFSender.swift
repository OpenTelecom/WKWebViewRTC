/*
* cordova-plugin-iosrtc v6.0.17
* Cordova iOS plugin exposing the ̶f̶u̶l̶l̶ WebRTC W3C JavaScript APIs.
* Copyright 2015-2017 eFace2Face, Inc. (https://eface2face.com)
* Copyright 2015-2019 BasqueVoIPMafia (https://github.com/BasqueVoIPMafia)
* Copyright 2019 Cordova-RTC (https://github.com/cordova-rtc)
* The MIT License (MIT)
*/

import Foundation
import WebRTC

class iRTCDTMFSender : NSObject {
	var rtcRtpSender: RTCRtpSender?
	var eventListener: ((_ data: NSDictionary) -> Void)?

	/**
	 * Constructor for pc.createDTMFSender().
	 */
	init(
		rtcPeerConnection: RTCPeerConnection,
		track: RTCMediaStreamTrack,
		streamId: String,
		eventListener: @escaping (_ data: NSDictionary) -> Void
		) {
		NSLog("iRTCDTMFSender#init()")

		self.eventListener = eventListener
		
		// TODO check if new rtcRtpSender can be used one Unified-Plan merged
		//let streamIds = [streamId]
		//self.rtcRtpSender = rtcPeerConnection.add(track, streamIds: streamIds);
		self.rtcRtpSender = rtcPeerConnection.senders[0]

		if self.rtcRtpSender == nil {
			NSLog("iRTCDTMFSender#init() | rtcPeerConnection.createDTMFSenderForTrack() failed")
			return
		}
	}

	deinit {
		NSLog("iRTCDTMFSender#deinit()")
	}

	func run() {
		NSLog("iRTCDTMFSender#run()")
	}

	func insertDTMF(_ tones: String, duration: TimeInterval, interToneGap: TimeInterval) {
		NSLog("iRTCDTMFSender#insertDTMF()")

		let dtmfSender = self.rtcRtpSender?.dtmfSender
		let durationMs = duration / 100
		let interToneGapMs = interToneGap / 100
		let result = dtmfSender!.insertDtmf(tones, duration: durationMs, interToneGap: interToneGapMs)
		if !result {
			NSLog("iRTCDTMFSender#indertDTMF() | RTCDTMFSender#indertDTMF() failed")
		}
	}

	/**
	 * Methods inherited from RTCDTMFSenderDelegate.
	 */
	func toneChange(_ tone: String) {
		NSLog("iRTCDTMFSender | tone change [tone:%@]", tone)

		if self.eventListener != nil {
			self.eventListener!([
				"type": "tonechange",
				"tone": tone
			])
		}
	}
}
