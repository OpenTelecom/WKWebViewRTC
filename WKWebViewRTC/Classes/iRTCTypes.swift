/*
* cordova-plugin-iosrtc v6.0.17
* Cordova iOS plugin exposing the ̶f̶u̶l̶l̶ WebRTC W3C JavaScript APIs.
* Copyright 2015-2017 eFace2Face, Inc. (https://eface2face.com)
* Copyright 2015-2019 BasqueVoIPMafia (https://github.com/BasqueVoIPMafia)
* Copyright 2019 Cordova-RTC (https://github.com/cordova-rtc)
* The MIT License (MIT)
*/

import WebRTC
struct iRTCTypes {
	static let signalingStates = [
		RTCSignalingState.stable.rawValue:             "stable",
		RTCSignalingState.haveLocalOffer.rawValue:     "have-local-offer",
		RTCSignalingState.haveLocalPrAnswer.rawValue:  "have-local-pranswer",
		RTCSignalingState.haveRemoteOffer.rawValue:    "have-remote-offer",
		RTCSignalingState.haveRemotePrAnswer.rawValue: "have-remote-pranswer",
		RTCSignalingState.closed.rawValue:             "closed"
	]

	static let iceGatheringStates = [
		RTCIceGatheringState.new.rawValue:            "new",
		RTCIceGatheringState.gathering.rawValue:      "gathering",
		RTCIceGatheringState.complete.rawValue:       "complete"
	]

	static let iceConnectionStates = [
		RTCIceConnectionState.new.rawValue:            "new",
		RTCIceConnectionState.checking.rawValue:       "checking",
		RTCIceConnectionState.connected.rawValue:      "connected",
		RTCIceConnectionState.completed.rawValue:      "completed",
		RTCIceConnectionState.failed.rawValue:         "failed",
		RTCIceConnectionState.disconnected.rawValue:   "disconnected",
		RTCIceConnectionState.closed.rawValue:         "closed"
	]

	static let dataChannelStates = [
		RTCDataChannelState.connecting.rawValue: "connecting",
		RTCDataChannelState.open.rawValue:       "open",
		RTCDataChannelState.closing.rawValue:    "closing",
		RTCDataChannelState.closed.rawValue:     "closed"
	]

	static let mediaStreamTrackStates = [
		RTCMediaStreamTrackState.live.rawValue:		"live",
		RTCMediaStreamTrackState.ended.rawValue:	"ended"
	]

}
