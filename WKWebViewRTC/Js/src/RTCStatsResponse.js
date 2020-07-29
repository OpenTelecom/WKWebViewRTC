/*
 * cordova-plugin-iosrtc v6.0.12
 * Cordova iOS plugin exposing the ̶f̶u̶l̶l̶ WebRTC W3C JavaScript APIs.
 * Copyright 2015-2017 eFace2Face, Inc. (https://eface2face.com)
 * Copyright 2015-2019 BasqueVoIPMafia (https://github.com/BasqueVoIPMafia)
 * Copyright 2019 Cordova-RTC (https://github.com/cordova-rtc)
 * The MIT License (MIT)
 */

/**
 * Expose the RTCStatsResponse class.
 */
module.exports = RTCStatsResponse;

function RTCStatsResponse(data) {
	data = data || [];

	this.result = function () {
		return data;
	};

	this.forEach = function (callback, thisArg) {
		return data.forEach(callback, thisArg);
	};

	this.namedItem = function () {
		return null;
	};
}
