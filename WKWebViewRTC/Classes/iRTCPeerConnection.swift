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

class iRTCPeerConnection : NSObject, RTCPeerConnectionDelegate {

	var rtcPeerConnectionFactory: RTCPeerConnectionFactory
	var rtcPeerConnection: RTCPeerConnection!
	var pluginRTCPeerConnectionConfig: iRTCPeerConnectionConfig
	var pluginRTCPeerConnectionConstraints: iRTCPeerConnectionConstraints
	// iRTCDataChannel dictionary.
	var pluginRTCDataChannels: [Int : iRTCDataChannel] = [:]
	// iRTCDTMFSender dictionary.
	
	var pluginRTCDTMFSenders: [Int : iRTCDTMFSender] = [:]

	var eventListener: (_ data: NSDictionary) -> Void
	var eventListenerForAddStream: (_ pluginMediaStream: iMediaStream) -> Void
	var eventListenerForRemoveStream: (_ pluginMediaStream: iMediaStream) -> Void
	var eventListenerForAddTrack: (_ pluginMediaStreamTrack: iMediaStreamTrack) -> Void
	var eventListenerForRemoveTrack: (_ pluginMediaStreamTrack: iMediaStreamTrack) -> Void

	var onCreateLocalDescriptionSuccessCallback: ((_ rtcSessionDescription: RTCSessionDescription) -> Void)!
	var onCreateLocalDescriptionFailureCallback: ((_ error: Error) -> Void)!
	var onCreateRemoteDescriptionSuccessCallback: ((_ rtcSessionDescription: RTCSessionDescription) -> Void)!
	var onCreateRemoteDescriptionFailureCallback: ((_ error: Error) -> Void)!

	var onSetDescriptionSuccessCallback: (() -> Void)!
	var onSetDescriptionFailureCallback: ((_ error: Error) -> Void)!

	var onGetStatsCallback: ((_ array: NSArray) -> Void)!

	var pluginMediaStreams: [String : iMediaStream]! = [:]
	var pluginMediaTracks: [String : iMediaStreamTrack]! = [:]

	var trackIdsToSenders: [String : RTCRtpSender] = [:]
	var trackIdsToReceivers: [String : RTCRtpReceiver] = [:]

	var isAudioInputSelected: Bool = false

	init(
		rtcPeerConnectionFactory: RTCPeerConnectionFactory,
		pcConfig: NSDictionary?,
		pcConstraints: NSDictionary?,
		eventListener: @escaping (_ data: NSDictionary) -> Void,
		eventListenerForAddStream: @escaping (_ pluginMediaStream: iMediaStream) -> Void,
		eventListenerForRemoveStream: @escaping (_ pluginMediaStream: iMediaStream) -> Void,
		eventListenerForAddTrack: @escaping (_ pluginMediaStreamTrack: iMediaStreamTrack) -> Void,
		eventListenerForRemoveTrack: @escaping (_ pluginMediaStreamTrack: iMediaStreamTrack) -> Void
	) {
		NSLog("iRTCPeerConnection#init()")

		self.rtcPeerConnectionFactory = rtcPeerConnectionFactory
		self.pluginRTCPeerConnectionConfig = iRTCPeerConnectionConfig(pcConfig: pcConfig)
		self.pluginRTCPeerConnectionConstraints = iRTCPeerConnectionConstraints(pcConstraints: pcConstraints)
		self.eventListener = eventListener
		self.eventListenerForAddStream = eventListenerForAddStream
		self.eventListenerForRemoveStream = eventListenerForRemoveStream
		self.eventListenerForAddTrack = eventListenerForAddTrack
		self.eventListenerForRemoveTrack = eventListenerForRemoveTrack
	}

	deinit {
		NSLog("iRTCPeerConnection#deinit()")
		self.pluginRTCDTMFSenders = [:]
	}

	func run() {
		NSLog("iRTCPeerConnection#run()")

		self.rtcPeerConnection = self.rtcPeerConnectionFactory.peerConnection(
			with: self.pluginRTCPeerConnectionConfig.getConfiguration(),
			constraints: self.pluginRTCPeerConnectionConstraints.getConstraints(),
			delegate: self
		)
	}

	func createOffer(
		_ options: NSDictionary?,
		callback: @escaping (_ data: NSDictionary) -> Void,
		errback: @escaping (_ error: Error) -> Void
	) {
		NSLog("iRTCPeerConnection#createOffer()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCPeerConnectionConstraints = iRTCPeerConnectionConstraints(pcConstraints: options)


		self.onCreateLocalDescriptionSuccessCallback = { (rtcSessionDescription: RTCSessionDescription) -> Void in
			NSLog("iRTCPeerConnection#createOffer() | success callback")

			let data = [
				"type": RTCSessionDescription.string(for: rtcSessionDescription.type),
				"sdp": rtcSessionDescription.sdp
			] as [String : Any]

			callback(data as NSDictionary)
		}

		self.onCreateLocalDescriptionFailureCallback = { (error: Error) -> Void in
			NSLog("iRTCPeerConnection#createOffer() | failure callback: %@", String(describing: error))

			errback(error)
		}

		self.rtcPeerConnection.offer(for: pluginRTCPeerConnectionConstraints.getConstraints(), completionHandler: {
			(sdp: RTCSessionDescription?, error: Error?) in
			if (error == nil) {
				self.onCreateLocalDescriptionSuccessCallback(sdp!);
			} else {
				self.onCreateLocalDescriptionFailureCallback(error!);
			}
		})
	}


	func createAnswer(
		_ options: NSDictionary?,
		callback: @escaping (_ data: NSDictionary) -> Void,
		errback: @escaping (_ error: Error) -> Void
	) {
		NSLog("iRTCPeerConnection#createAnswer()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCPeerConnectionConstraints = iRTCPeerConnectionConstraints(pcConstraints: options)

		self.onCreateRemoteDescriptionSuccessCallback = { (rtcSessionDescription: RTCSessionDescription) -> Void in
			NSLog("iRTCPeerConnection#createAnswer() | success callback")

			let data = [
				"type": RTCSessionDescription.string(for: rtcSessionDescription.type),
				"sdp": rtcSessionDescription.sdp
			] as [String : Any]

			callback(data as NSDictionary)
		}

		self.onCreateRemoteDescriptionFailureCallback = { (error: Error) -> Void in
			NSLog("iRTCPeerConnection#createAnswer() | failure callback: %@", String(describing: error))

			errback(error)
		}

		self.rtcPeerConnection.answer(for: pluginRTCPeerConnectionConstraints.getConstraints(), completionHandler: {
			(sdp: RTCSessionDescription?, error: Error?) in
			if (error == nil) {
				self.onCreateRemoteDescriptionSuccessCallback(sdp!)
			} else {
				self.onCreateRemoteDescriptionFailureCallback(error!)
			}
		})
	}

	func setLocalDescription(
		_ desc: NSDictionary,
		callback: @escaping (_ data: NSDictionary) -> Void,
		errback: @escaping (_ error: Error) -> Void
	) {
		NSLog("iRTCPeerConnection#setLocalDescription()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let type = desc.object(forKey: "type") as? String ?? ""
		let sdp = desc.object(forKey: "sdp") as? String ?? ""
		let sdpType = RTCSessionDescription.type(for: type)
		let rtcSessionDescription = RTCSessionDescription(type: sdpType, sdp: sdp)

		self.onSetDescriptionSuccessCallback = { [unowned self] () -> Void in
			NSLog("iRTCPeerConnection#setLocalDescription() | success callback")
			let data = [
				"type": RTCSessionDescription.string(for: self.rtcPeerConnection.localDescription!.type),
				"sdp": self.rtcPeerConnection.localDescription!.sdp
			] as [String : Any]

			callback(data as NSDictionary)
		}

		self.onSetDescriptionFailureCallback = { (error: Error) -> Void in
			NSLog("iRTCPeerConnection#setLocalDescription() | failure callback: %@", String(describing: error))

			errback(error)
		}

		self.rtcPeerConnection.setLocalDescription(rtcSessionDescription, completionHandler: {
			(error: Error?) in
			if (error == nil) {
				self.onSetDescriptionSuccessCallback();
			} else {
				self.onSetDescriptionFailureCallback(error!);
			}
		})
	}


	func setRemoteDescription(
		_ desc: NSDictionary,
		callback: @escaping (_ data: NSDictionary) -> Void,
		errback: @escaping (_ error: Error) -> Void
	) {
		NSLog("iRTCPeerConnection#setRemoteDescription()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let type = desc.object(forKey: "type") as? String ?? ""
		let sdp = desc.object(forKey: "sdp") as? String ?? ""
		let sdpType = RTCSessionDescription.type(for: type)
		let rtcSessionDescription = RTCSessionDescription(type: sdpType, sdp: sdp)

		self.onSetDescriptionSuccessCallback = { [unowned self] () -> Void in
			NSLog("iRTCPeerConnection#setRemoteDescription() | success callback")

			let data = [
				"type": RTCSessionDescription.string(for: self.rtcPeerConnection.remoteDescription!.type),
				"sdp": self.rtcPeerConnection.remoteDescription!.sdp
			]

			callback(data as NSDictionary)
		}

		self.onSetDescriptionFailureCallback = { (error: Error) -> Void in
			NSLog("iRTCPeerConnection#setRemoteDescription() | failure callback: %@", String(describing: error))

			errback(error)
		}

		self.rtcPeerConnection.setRemoteDescription(rtcSessionDescription, completionHandler: {
			(error: Error?) in
			if (error == nil) {
				self.onSetDescriptionSuccessCallback();
			} else {
				self.onSetDescriptionFailureCallback(error!);
			}
		})
	}

	func addIceCandidate(
		_ candidate: NSDictionary,
		callback: (_ data: NSDictionary) -> Void,
		errback: () -> Void
	) {
		NSLog("iRTCPeerConnection#addIceCandidate()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let sdpMid = candidate.object(forKey: "sdpMid") as? String ?? ""
		let sdpMLineIndex = candidate.object(forKey: "sdpMLineIndex") as? Int32 ?? 0
		let candidate = candidate.object(forKey: "candidate") as? String ?? ""

		self.rtcPeerConnection!.add(RTCIceCandidate(
			sdp: candidate,
			sdpMLineIndex: sdpMLineIndex,
			sdpMid: sdpMid
		))

		// TODO detect RTCIceCandidate failure
		let result = true

		// TODO check if it still needed or moved elsewhere
		if !self.isAudioInputSelected {
			iRTCAudioController.restoreInputOutputAudioDevice()
			self.isAudioInputSelected = true
		}

		if result == true {
			var data: NSDictionary
			if self.rtcPeerConnection.remoteDescription != nil {
				data = [
					"remoteDescription": [
						"type": RTCSessionDescription.string(for: self.rtcPeerConnection.remoteDescription!.type),
						"sdp": self.rtcPeerConnection.remoteDescription!.sdp
					]
				]
			} else {
				data = [
					"remoteDescription": false
				]
			}

			callback(data)
		} else {
			errback()
		}
	}

	func addStream(_ pluginMediaStream: iMediaStream) -> Bool {
		NSLog("iRTCPeerConnection#addStream()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return false
		}

		if (IsUnifiedPlan()) {

			var streamAdded : Bool = false;
			let streamId = pluginMediaStream.rtcMediaStream.streamId;
			for (_, pluginMediaTrack) in pluginMediaStream.audioTracks {
				streamAdded = self.addTrack(pluginMediaTrack, [streamId]) && streamAdded;
			}

			for (_, pluginMediaTrack) in pluginMediaStream.videoTracks {
				streamAdded = self.addTrack(pluginMediaTrack, [streamId]) && streamAdded;
			}

			return streamAdded;

		} else {
			self.rtcPeerConnection.add(pluginMediaStream.rtcMediaStream)
		}

		return true
	}

	func removeStream(_ pluginMediaStream: iMediaStream) {
		NSLog("iRTCPeerConnection#removeStream()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		if (IsUnifiedPlan()) {

			for (_, pluginMediaStream) in pluginMediaStream.audioTracks {
				self.removeTrack(pluginMediaStream)
			}

			for (_, pluginMediaStream) in pluginMediaStream.videoTracks {
				self.removeTrack(pluginMediaStream)
			}

		} else {
			self.rtcPeerConnection.remove(pluginMediaStream.rtcMediaStream)
		}
	}

	func IsUnifiedPlan() -> Bool {
		return rtcPeerConnection.configuration.sdpSemantics == RTCSdpSemantics.unifiedPlan;
	}

	func addTrack(_ pluginMediaTrack: iMediaStreamTrack, _ streamIds: [String]) -> Bool {
		NSLog("iRTCPeerConnection#addTrack()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return false
		}

		let rtcMediaStreamTrack = pluginMediaTrack.rtcMediaStreamTrack;
		var rtcSender = trackIdsToSenders[rtcMediaStreamTrack.trackId];
		if (rtcSender == nil) {
			rtcSender = self.rtcPeerConnection.add(rtcMediaStreamTrack, streamIds: streamIds)
			trackIdsToSenders[rtcMediaStreamTrack.trackId] = rtcSender;
			return true;
		}

		return false;
	}

	func removeTrack(_ pluginMediaTrack: iMediaStreamTrack) {
		NSLog("iRTCPeerConnection#removeTrack()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let rtcMediaStreamTrack = pluginMediaTrack.rtcMediaStreamTrack;
		let rtcSender = trackIdsToSenders[rtcMediaStreamTrack.trackId];

		if (rtcSender != nil) {
			self.rtcPeerConnection.removeTrack(rtcSender!)
			trackIdsToSenders[rtcMediaStreamTrack.trackId] = nil
		}
	}

	func createDataChannel(
		_ dcId: Int,
		label: String,
		options: NSDictionary?,
		eventListener: @escaping (_ data: NSDictionary) -> Void,
		eventListenerForBinaryMessage: @escaping (_ data: Data) -> Void
	) {
		NSLog("iRTCPeerConnection#createDataChannel()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCDataChannel = iRTCDataChannel(
			rtcPeerConnection: rtcPeerConnection,
			label: label,
			options: options,
			eventListener: eventListener,
			eventListenerForBinaryMessage: eventListenerForBinaryMessage
		)

		// Store the pluginRTCDataChannel into the dictionary.
		self.pluginRTCDataChannels[dcId] = pluginRTCDataChannel

		// Run it.
		pluginRTCDataChannel.run()
	}

	func RTCDataChannel_setListener(
		_ dcId: Int,
		eventListener: @escaping (_ data: NSDictionary) -> Void,
		eventListenerForBinaryMessage: @escaping (_ data: Data) -> Void
	) {
		NSLog("iRTCPeerConnection#RTCDataChannel_setListener()")

		let pluginRTCDataChannel = self.pluginRTCDataChannels[dcId]

		if pluginRTCDataChannel == nil {
			return;
		}

		// Set the eventListener.
		pluginRTCDataChannel!.setListener(eventListener,
			eventListenerForBinaryMessage: eventListenerForBinaryMessage
		)
	}


	func createDTMFSender(
		_ dsId: Int,
		track: iMediaStreamTrack,
		eventListener: @escaping (_ data: NSDictionary) -> Void
	) {
		NSLog("iRTCPeerConnection#createDTMFSender()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCDTMFSender = iRTCDTMFSender(
			rtcPeerConnection: self.rtcPeerConnection,
			track: track.rtcMediaStreamTrack,
			streamId: String(dsId), //TODO
			eventListener: eventListener
		)

		// Store the pluginRTCDTMFSender into the dictionary.
		self.pluginRTCDTMFSenders[dsId] = pluginRTCDTMFSender

		// Run it.
		pluginRTCDTMFSender.run()
	}

	func getStats(
		_ pluginMediaStreamTrack: iMediaStreamTrack?,
		callback: @escaping (_ data: [[String:Any]]) -> Void,
		errback: (_ error: NSError) -> Void
	) {
		NSLog("iRTCPeerConnection#getStats()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		self.rtcPeerConnection.stats(for: pluginMediaStreamTrack?.rtcMediaStreamTrack, statsOutputLevel: RTCStatsOutputLevel.standard, completionHandler: { (stats: [RTCLegacyStatsReport]) in
			var data: [[String:Any]] = []
			for i in 0 ..< stats.count {
				let report: RTCLegacyStatsReport = stats[i]
				data.append([
					"reportId" : report.reportId,
					"type" : report.type,
					"timestamp" : report.timestamp,
					"values" : report.values
				])
			}
			NSLog("Stats:\n %@", data)
			callback(data)
		})
	}

	func close() {
		NSLog("iRTCPeerConnection#close()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		for (_, pluginMediaStream) in self.pluginMediaStreams {
			self.eventListenerForRemoveStream(pluginMediaStream)
		}
		
		for (_, pluginMediaTrack) in self.pluginMediaTracks {
			self.eventListenerForRemoveTrack(pluginMediaTrack)
		}

		self.pluginMediaTracks = [:];
		self.pluginMediaStreams = [:];

		self.rtcPeerConnection.close()
	}

	func RTCDataChannel_sendString(
		_ dcId: Int,
		data: String,
		callback: (_ data: NSDictionary) -> Void
	) {
		NSLog("iRTCPeerConnection#RTCDataChannel_sendString()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCDataChannel = self.pluginRTCDataChannels[dcId]

		if pluginRTCDataChannel == nil {
			return;
		}

		pluginRTCDataChannel!.sendString(data, callback: callback)
	}


	func RTCDataChannel_sendBinary(
		_ dcId: Int,
		data: Data,
		callback: (_ data: NSDictionary) -> Void
	) {
		NSLog("iRTCPeerConnection#RTCDataChannel_sendBinary()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCDataChannel = self.pluginRTCDataChannels[dcId]

		if pluginRTCDataChannel == nil {
			return;
		}

		pluginRTCDataChannel!.sendBinary(data, callback: callback)
	}


	func RTCDataChannel_close(_ dcId: Int) {
		NSLog("iRTCPeerConnection#RTCDataChannel_close()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCDataChannel = self.pluginRTCDataChannels[dcId]

		if pluginRTCDataChannel == nil {
			return;
		}

		pluginRTCDataChannel!.close()

		// Remove the pluginRTCDataChannel from the dictionary.
		self.pluginRTCDataChannels[dcId] = nil
	}


	func RTCDTMFSender_insertDTMF(
		_ dsId: Int,
		tones: String,
		duration: Double,
		interToneGap: Double
	) {
		NSLog("iRTCPeerConnection#RTCDTMFSender_insertDTMF()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCDTMFSender = self.pluginRTCDTMFSenders[dsId]
		if pluginRTCDTMFSender == nil {
			return
		}

		pluginRTCDTMFSender!.insertDTMF(tones, duration: duration as TimeInterval, interToneGap: interToneGap as TimeInterval)
	}

	/**
	 * Methods inherited from RTCPeerConnectionDelegate.
	 */

	private func getiMediaStream(_ stream: RTCMediaStream?) -> iMediaStream? {

		if (stream == nil) {
			return nil;
		}

		var currentMediaStream : iMediaStream? = nil;

		for (_, pluginMediaStream) in self.pluginMediaStreams {
			if (pluginMediaStream.rtcMediaStream.streamId == stream!.streamId) {
				currentMediaStream = pluginMediaStream;
				break;
			}
		}

		if (currentMediaStream == nil) {

			currentMediaStream = iMediaStream(rtcMediaStream: stream!)

			currentMediaStream!.run()

			// Let the plugin store it in its dictionary.
			self.pluginMediaStreams[currentMediaStream!.id] = currentMediaStream;
			
			// Fixes issue #576
			self.eventListenerForAddStream(currentMediaStream!)
		}

		return currentMediaStream;
	}

	private func getiMediaStreamTrack(_ rtpReceiver: RTCRtpReceiver) -> iMediaStreamTrack? {
		
		if (rtpReceiver.track == nil) {
			return nil;
		}

		var currentMediaStreamTrack : iMediaStreamTrack? = nil;

		for (_, pluginMediaTrack) in self.pluginMediaTracks {
			if (pluginMediaTrack.rtcMediaStreamTrack.trackId == rtpReceiver.track!.trackId) {
				currentMediaStreamTrack = pluginMediaTrack;
				break;
			}
		}

		if (currentMediaStreamTrack == nil) {

			currentMediaStreamTrack = iMediaStreamTrack(rtcMediaStreamTrack: rtpReceiver.track!)

			currentMediaStreamTrack!.run()

			// Let the plugin store it in its dictionary.
			self.pluginMediaTracks[currentMediaStreamTrack!.id] = currentMediaStreamTrack;
			self.trackIdsToReceivers[currentMediaStreamTrack!.id] = rtpReceiver;
			
			// Fixes issue #576
			self.eventListenerForAddTrack(currentMediaStreamTrack!)
		}

		return currentMediaStreamTrack;
	}

	/** Called when media is received on a new stream from remote peer. */
	func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
		NSLog("iRTCPeerConnection | onaddstream")

		let pluginMediaStream = getiMediaStream(stream);

		// Fire the 'addstream' event so the JS will create a new MediaStream.
		self.eventListener([
			"type": "addstream",
			"streamId": pluginMediaStream!.id,
			"stream": pluginMediaStream!.getJSON()
		])
	}

	/** Called when a remote peer closes a stream. */
	func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
		NSLog("iRTCPeerConnection | onremovestream")

		let pluginMediaStream = getiMediaStream(stream);

		self.eventListenerForRemoveStream(pluginMediaStream!)

		// Let the plugin remove it from its dictionary.
		pluginMediaStreams[pluginMediaStream!.id] = nil;

		self.eventListener([
			"type": "removestream",
			"streamId": pluginMediaStream!.id
		])
	}

	/** New track as been added. */
	func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams:[RTCMediaStream]) {

		NSLog("iRTCPeerConnection | onaddtrack")

		let pluginMediaTrack = getiMediaStreamTrack(rtpReceiver);

		// Add stream only if available in case of Unified-Plan of track event without stream
		// TODO investigate why no stream sometimes with Unified-Plan and confirm that expexted behavior.

		if (streams.isEmpty) {
			self.eventListener([
				"type": "track",
				"track": pluginMediaTrack!.getJSON(),
			])
		} else {
			let pluginMediaStream = getiMediaStream(streams[0]);

			self.eventListener([
				"type": "track",
				"track": pluginMediaTrack!.getJSON(),
				"streamId": pluginMediaStream!.id,
				"stream": pluginMediaStream!.getJSON()
			])
		}
	}

	/** Called when the SignalingState changed. */

	// TODO: remove on M75
	// This was already fixed in M-75, but note that "Issue 740501: RTCPeerConnection.onnegotiationneeded can sometimes fire multiple times in a row" was a prerequisite of Perfect Negotiation as well.
	// https://stackoverflow.com/questions/48963787/failed-to-set-local-answer-sdp-called-in-wrong-state-kstable
	// https://bugs.chromium.org/p/chromium/issues/detail?id=740501
	// https://bugs.chromium.org/p/chromium/issues/detail?id=980872
	var isNegotiating = false;

	func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
		let state_str = iRTCTypes.signalingStates[stateChanged.rawValue] as String?

		NSLog("iRTCPeerConnection | onsignalingstatechange [signalingState:%@]", String(describing: state_str))

		isNegotiating = (state_str != "stable")

		self.eventListener([
			"type": "signalingstatechange",
			"signalingState": state_str!
		])
	}

	/** Called when negotiation is needed, for example ICE has restarted. */
	func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
		NSLog("iRTCPeerConnection | onnegotiationeeded")

		if (!IsUnifiedPlan() && isNegotiating) {
		  NSLog("iRTCPeerConnection#addStream() | signalingState is stable skip nested negotiations when using plan-b")
		  return;
		}

		self.eventListener([
			"type": "negotiationneeded"
		])
	}

	/** Called any time the IceConnectionState changes. */
	func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
		let state_str = iRTCTypes.iceConnectionStates[newState.rawValue]

		NSLog("iRTCPeerConnection | oniceconnectionstatechange [iceConnectionState:%@]", String(describing: state_str))

		self.eventListener([
			"type": "iceconnectionstatechange",
			"iceConnectionState": state_str as Any
		])
	}

	/** Called any time the IceGatheringState changes. */
	func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
		let state_str = iRTCTypes.iceGatheringStates[newState.rawValue]

		NSLog("iRTCPeerConnection | onicegatheringstatechange [iceGatheringState:%@]", String(describing: state_str))

		self.eventListener([
			"type": "icegatheringstatechange",
			"iceGatheringState": state_str as Any
		])

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		// Emit an empty candidate if iceGatheringState is "complete".
		if newState.rawValue == RTCIceGatheringState.complete.rawValue && self.rtcPeerConnection.localDescription != nil {
			self.eventListener([
				"type": "icecandidate",
				// NOTE: Cannot set null as value.
				"candidate": false,
				"localDescription": [
					"type": RTCSessionDescription.string(for: self.rtcPeerConnection.localDescription!.type),
					"sdp": self.rtcPeerConnection.localDescription!.sdp
				] as [String : Any]
			])
		}
	}

	/** New ice candidate has been found. */
	func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
		NSLog("iRTCPeerConnection | onicecandidate [sdpMid:%@, sdpMLineIndex:%@, candidate:%@]",
			  String(candidate.sdpMid!), String(candidate.sdpMLineIndex), String(candidate.sdp))

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		self.eventListener([
			"type": "icecandidate",
			"candidate": [
				"sdpMid": candidate.sdpMid as Any,
				"sdpMLineIndex": candidate.sdpMLineIndex,
				"candidate": candidate.sdp
			],
			"localDescription": [
				"type": RTCSessionDescription.string(for: self.rtcPeerConnection.localDescription!.type),
				"sdp": self.rtcPeerConnection.localDescription!.sdp
			] as [String : Any]
		])
	}

	/** Called when a group of local Ice candidates have been removed. */
	func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
		NSLog("iRTCPeerConnection | removeicecandidates")
	}

	/** New data channel has been opened. */
	func peerConnection(_ peerConnection: RTCPeerConnection, didOpen rtcDataChannel: RTCDataChannel) {
		NSLog("iRTCPeerConnection | ondatachannel")

		let dcId = iUtils.randomInt(10000, max:99999)
		let pluginRTCDataChannel = iRTCDataChannel(
			rtcDataChannel: rtcDataChannel
		)

		// Store the pluginRTCDataChannel into the dictionary.
		self.pluginRTCDataChannels[dcId] = pluginRTCDataChannel

		// Run it.
		pluginRTCDataChannel.run()

		// Fire the 'datachannel' event so the JS will create a new RTCDataChannel.
		self.eventListener([
			"type": "datachannel",
			"channel": [
				"dcId": dcId,
				"label": rtcDataChannel.label,
				"ordered": rtcDataChannel.isOrdered,
				"maxPacketLifeTime": rtcDataChannel.maxPacketLifeTime,
				"maxRetransmits": rtcDataChannel.maxRetransmits,
				"protocol": rtcDataChannel.`protocol`,
				"negotiated": rtcDataChannel.isNegotiated,
				"id": rtcDataChannel.channelId,
				"readyState": iRTCTypes.dataChannelStates[rtcDataChannel.readyState.rawValue] as Any,
				"bufferedAmount": rtcDataChannel.bufferedAmount
			]
		])
	}
}
