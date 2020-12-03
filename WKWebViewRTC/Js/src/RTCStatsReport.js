/*
 * cordova-plugin-iosrtc v6.0.17
 * Cordova iOS plugin exposing the ̶f̶u̶l̶l̶ WebRTC W3C JavaScript APIs.
 * Copyright 2015-2017 eFace2Face, Inc. (https://eface2face.com)
 * Copyright 2015-2019 BasqueVoIPMafia (https://github.com/BasqueVoIPMafia)
 * Copyright 2019 Cordova-RTC (https://github.com/cordova-rtc)
 * The MIT License (MIT)
 */

/**
 * Expose the RTCStatsReport class.
 */
module.exports = RTCStatsReport;

function RTCStatsReport(data) {
	data = data || {};

	this.id = data.reportId;
	this.timestamp = data.timestamp;
	this.type = data.type;

	this.names = function () {
		return Object.keys(data.values);
	};

	this.stat = function (key) {
		return data.values[key] || '';
	};
}
