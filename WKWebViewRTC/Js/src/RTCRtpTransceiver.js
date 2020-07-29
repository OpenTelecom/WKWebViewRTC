/*
 * cordova-plugin-iosrtc v6.0.12
 * Cordova iOS plugin exposing the ̶f̶u̶l̶l̶ WebRTC W3C JavaScript APIs.
 * Copyright 2015-2017 eFace2Face, Inc. (https://eface2face.com)
 * Copyright 2015-2019 BasqueVoIPMafia (https://github.com/BasqueVoIPMafia)
 * Copyright 2019 Cordova-RTC (https://github.com/cordova-rtc)
 * The MIT License (MIT)
 */

/**
 * Expose the RTCRtpTransceiver class.
 */
module.exports = RTCRtpTransceiver;


function RTCRtpTransceiver(data) {
	data = data || {};

	this.receiver = data.receiver;
	this.sender = data.sender;
}

// TODO
// https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpTransceiver/currentDirection
// https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpTransceiverDirection
// https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpTransceiver/mid
// https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpTransceiver/stop
