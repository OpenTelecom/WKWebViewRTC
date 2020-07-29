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
