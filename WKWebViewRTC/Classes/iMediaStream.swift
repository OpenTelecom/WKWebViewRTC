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

class iMediaStream : NSObject {

	var rtcMediaStream: RTCMediaStream
	var id: String
	var audioTracks: [String : iMediaStreamTrack] = [:]
	var videoTracks: [String : iMediaStreamTrack] = [:]
	var eventListener: ((_ data: NSDictionary) -> Void)?
	var eventListenerForAddTrack: ((_ pluginMediaStreamTrack: iMediaStreamTrack) -> Void)?
	var eventListenerForRemoveTrack: ((_ pluginMediaStreamTrack: iMediaStreamTrack) -> Void)?

	/**
	 * Constructor for pc.onaddstream event and getUserMedia().
	 */
	init(rtcMediaStream: RTCMediaStream, streamId: String? = nil) {
		NSLog("iMediaStream#init()")

		self.rtcMediaStream = rtcMediaStream;

		if (streamId == nil) {
			// Handle possible duplicate remote trackId with  janus or short duplicate name
			// See: https://github.com/cordova-rtc/cordova-plugin-iosrtc/issues/432
			if (rtcMediaStream.streamId.count < 36) {
				self.id = rtcMediaStream.streamId + "_" + UUID().uuidString;
			} else {
				self.id = rtcMediaStream.streamId;
			}
		} else {
			self.id = streamId!;
		}

		for track: RTCMediaStreamTrack in (self.rtcMediaStream.audioTracks as Array<RTCMediaStreamTrack>) {
			let pluginMediaStreamTrack = iMediaStreamTrack(rtcMediaStreamTrack: track)

			pluginMediaStreamTrack.run()
			self.audioTracks[pluginMediaStreamTrack.id] = pluginMediaStreamTrack
		}

		for track: RTCMediaStreamTrack in (self.rtcMediaStream.videoTracks as Array<RTCMediaStreamTrack>) {
			let pluginMediaStreamTrack = iMediaStreamTrack(rtcMediaStreamTrack: track)

			pluginMediaStreamTrack.run()
			self.videoTracks[pluginMediaStreamTrack.id] = pluginMediaStreamTrack
		}
	}

	deinit {
		NSLog("iMediaStream#deinit()")
		stop();
	}

	func run() {
		NSLog("iMediaStream#run()")
	}

	func stop() {
		NSLog("iMediaStream#stop()")

		for (_, track) in audioTracks {
			if(self.eventListenerForRemoveTrack != nil) {
				self.eventListenerForRemoveTrack!(track)
			}
		}
		for (_, track) in videoTracks {
			if(self.eventListenerForRemoveTrack != nil) {
				self.eventListenerForRemoveTrack!(track)
			}
		}
	}

	func getJSON() -> NSDictionary {
		let json: NSMutableDictionary = [
			"id": self.id,
			"audioTracks": NSMutableDictionary(),
			"videoTracks": NSMutableDictionary()
		]

		for (id, pluginMediaStreamTrack) in self.audioTracks {
			(json["audioTracks"] as! NSMutableDictionary)[id] = pluginMediaStreamTrack.getJSON()
		}

		for (id, pluginMediaStreamTrack) in self.videoTracks {
			(json["videoTracks"] as! NSMutableDictionary)[id] = pluginMediaStreamTrack.getJSON()
		}

		return json as NSDictionary
	}

	func setListener(
		_ eventListener: @escaping (_ data: NSDictionary) -> Void,
		eventListenerForAddTrack: ((_ pluginMediaStreamTrack: iMediaStreamTrack) -> Void)?,
		eventListenerForRemoveTrack: ((_ pluginMediaStreamTrack: iMediaStreamTrack) -> Void)?
	) {
		NSLog("iMediaStream#setListener()")

		self.eventListener = eventListener
		self.eventListenerForAddTrack = eventListenerForAddTrack
		self.eventListenerForRemoveTrack = eventListenerForRemoveTrack
	}

	func addTrack(_ pluginMediaStreamTrack: iMediaStreamTrack) -> Bool {
		NSLog("iMediaStream#addTrack()")

		if pluginMediaStreamTrack.kind == "audio" {
			self.rtcMediaStream.addAudioTrack(pluginMediaStreamTrack.rtcMediaStreamTrack as! RTCAudioTrack)
			NSLog("iMediaStream#addTrack() | audio track added")
			self.audioTracks[pluginMediaStreamTrack.id] = pluginMediaStreamTrack
		} else if pluginMediaStreamTrack.kind == "video" {
			self.rtcMediaStream.addVideoTrack(pluginMediaStreamTrack.rtcMediaStreamTrack as! RTCVideoTrack)
			NSLog("iMediaStream#addTrack() | video track added")
			self.videoTracks[pluginMediaStreamTrack.id] = pluginMediaStreamTrack
		} else {
			return false
		}

		onAddTrack(pluginMediaStreamTrack)
		return true
	}

	func removeTrack(_ pluginMediaStreamTrack: iMediaStreamTrack) -> Bool {
		NSLog("iMediaStream#removeTrack()")

		if pluginMediaStreamTrack.kind == "audio" {
			self.audioTracks[pluginMediaStreamTrack.id] = nil
			self.rtcMediaStream.removeAudioTrack(pluginMediaStreamTrack.rtcMediaStreamTrack as! RTCAudioTrack)
			NSLog("iMediaStream#removeTrack() | audio track removed")
		} else if pluginMediaStreamTrack.kind == "video" {
			self.videoTracks[pluginMediaStreamTrack.id] = nil
			self.rtcMediaStream.removeVideoTrack(pluginMediaStreamTrack.rtcMediaStreamTrack as! RTCVideoTrack)
			NSLog("iMediaStream#removeTrack() | video track removed")
		} else {
			return false
		}

		onRemoveTrack(pluginMediaStreamTrack)
		return true
	}

	func onAddTrack(_ track: iMediaStreamTrack) {
		NSLog("iMediaStream | OnAddTrack [label:%@]", String(track.id))

		track.run()

		if self.eventListener != nil {
			self.eventListenerForAddTrack!(track)

			self.eventListener!([
				"type": "addtrack",
				"track": track.getJSON()
			])
		}
	}

	func onRemoveTrack(_ track: iMediaStreamTrack) {
		NSLog("iMediaStream | OnRemoveTrack [label:%@]", String(track.id))

		// It may happen that track was removed due to user action (removeTrack()).
		if self.audioTracks[track.id] != nil {
			self.audioTracks[track.id] = nil
		} else if self.videoTracks[track.id] != nil {
			self.videoTracks[track.id] = nil
		} else {
			return
		}

		if self.eventListener != nil {
			self.eventListenerForRemoveTrack!(track)

			self.eventListener!([
				"type": "removetrack",
				"track": [
					"id": track.id,
					"kind": track.kind
				]
			])
		}
	}
}
