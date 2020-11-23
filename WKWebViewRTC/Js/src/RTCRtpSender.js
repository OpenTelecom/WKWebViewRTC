/*
 * cordova-plugin-iosrtc v6.0.12
 * Cordova iOS plugin exposing the ̶f̶u̶l̶l̶ WebRTC W3C JavaScript APIs.
 * Copyright 2015-2017 eFace2Face, Inc. (https://eface2face.com)
 * Copyright 2015-2019 BasqueVoIPMafia (https://github.com/BasqueVoIPMafia)
 * Copyright 2019 Cordova-RTC (https://github.com/cordova-rtc)
 * The MIT License (MIT)
 */

/**
 * Expose the RTCRtpSender class.
 */
module.exports = RTCRtpSender;

function RTCRtpSender(data) {
	data = data || {};

    this._pc = data.pc;
	this.track = data.track;
    this.params = data.params || {};
}

RTCRtpSender.prototype.getParameters = function () {
    return this.params;
};

RTCRtpSender.prototype.setParameters = function (params) {
    Object.assign(this.params, params);
    return Promise.resolve(this.params);
};

RTCRtpSender.prototype.replaceTrack = function (withTrack) {
	var self = this,
		pc = self._pc;

	return new Promise(function (resolve, reject) {
		pc.removeTrack(self);
		pc.addTrack(withTrack);
		self.track = withTrack;

		// https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/negotiationneeded_event
		var event = new Event('negotiationneeded');
		pc.dispatchEvent('negotiationneeded', event);

		pc.addEventListener("signalingstatechange", function listener() {
			if (pc.signalingState === "closed") {
				pc.removeEventListener("signalingstatechange", listener);
				reject();
			} else if (pc.signalingState === "stable") {
				pc.removeEventListener("signalingstatechange", listener);
				resolve();
			}
		});
	});
};