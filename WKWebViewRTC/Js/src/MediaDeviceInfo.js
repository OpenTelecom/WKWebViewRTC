/*
 * cordova-plugin-iosrtc v6.0.15
 * Cordova iOS plugin exposing the ̶f̶u̶l̶l̶ WebRTC W3C JavaScript APIs.
 * Copyright 2015-2017 eFace2Face, Inc. (https://eface2face.com)
 * Copyright 2015-2019 BasqueVoIPMafia (https://github.com/BasqueVoIPMafia)
 * Copyright 2019 Cordova-RTC (https://github.com/cordova-rtc)
 * The MIT License (MIT)
 */

/**
 * Expose the MediaDeviceInfo class.
 */
module.exports = MediaDeviceInfo;

function MediaDeviceInfo(data) {
	data = data || {};

	Object.defineProperties(this, {
		// MediaDeviceInfo spec.
		deviceId: {
			value: data.deviceId
		},
		kind: {
			value: data.kind
		},
		label: {
			value: data.label
		},
		groupId: {
			value: data.groupId || ''
		},
		// SourceInfo old spec.
		id: {
			value: data.deviceId
		},
		// Deprecated, but useful until there is an alternative
		facing: {
			value: ''
		}
	});
}
