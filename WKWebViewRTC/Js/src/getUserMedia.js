/*
 * cordova-plugin-iosrtc v6.0.12
 * Cordova iOS plugin exposing the ̶f̶u̶l̶l̶ WebRTC W3C JavaScript APIs.
 * Copyright 2015-2017 eFace2Face, Inc. (https://eface2face.com)
 * Copyright 2015-2019 BasqueVoIPMafia (https://github.com/BasqueVoIPMafia)
 * Copyright 2019 Cordova-RTC (https://github.com/cordova-rtc)
 * The MIT License (MIT)
 */

/**
 * Expose the getUserMedia function.
 */
module.exports = getUserMedia;


/**
 * Dependencies.
 */
var
	debug = require('debug')('iosrtc:getUserMedia'),
	debugerror = require('debug')('iosrtc:ERROR:getUserMedia'),
	exec = require('./IOSExec'),
	MediaStream = require('./MediaStream'),
	Errors = require('./Errors');

function isPositiveInteger(number) {
	return typeof number === 'number' && number >= 0 && number % 1 === 0;
}

function isPositiveFloat(number) {
	return typeof number === 'number' && number >= 0;
}


function getUserMedia(constraints) {

	debug('[original constraints:%o]', constraints);

	var
		audioRequested = false,
		videoRequested = false,
		newConstraints = {};

	if (
		typeof constraints !== 'object' ||
			(!constraints.hasOwnProperty('audio') && !constraints.hasOwnProperty('video'))
	) {
		return new Promise(function (resolve, reject) {
			reject(new Errors.MediaStreamError('constraints must be an object with at least "audio" or "video" keys'));
		});
	}

	if (constraints.audio) {
		audioRequested = true;
	}

	if (constraints.video) {
		videoRequested = true;
	}

	// https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints
	// Example:
	//
	// getUserMedia({
	//  audio: {
	//      deviceId: 'azer-asdf-zxcv',
	//  },
	//  video: {
	//      deviceId: 'qwer-asdf-zxcv',
	//      aspectRatio: 1.777.
	//      facingMode: 'user',
	//      width: {
	//          min: 400,
	//          max: 600
	//      },
	//      frameRate: {
	//          min: 1.0,
	//          max: 60.0
	//      }
	//  }
	// });

	/*
	// See: https://www.w3.org/TR/mediacapture-streams/#media-track-constraints
	dictionary MediaTrackConstraintSet {
	 ConstrainULong     width;
	 ConstrainULong     height;
	 ConstrainDouble    aspectRatio;
	 ConstrainDouble    frameRate;
	 ConstrainDOMString facingMode;
	 ConstrainDOMString resizeMode;
	 ConstrainULong     sampleRate;
	 ConstrainULong     sampleSize;
	 ConstrainBoolean   echoCancellation;
	 ConstrainBoolean   autoGainControl;
	 ConstrainBoolean   noiseSuppression;
	 ConstrainDouble    latency;
	 ConstrainULong     channelCount;
	 ConstrainDOMString deviceId;
	 ConstrainDOMString groupId;
	};

	 // typedef ([Clamp] unsigned long or ConstrainULongRange) ConstrainULong;
	 // We convert unsigned long to ConstrainULongRange.exact

	 dictionary ULongRange {
		[Clamp] unsigned long max;
		[Clamp] unsigned long min;
	 };

	 dictionary ConstrainULongRange : ULongRange {
		  [Clamp] unsigned long exact;
		  [Clamp] unsigned long ideal;
	 };

	 // See: https://www.w3.org/TR/mediacapture-streams/#dom-doublerange
	 // typedef (double or ConstrainDoubleRange) ConstrainDouble;
	 // We convert double to ConstrainDoubleRange.exact
	 dictionary ConstrainDouble {
		double max;
		double min;
	 };

	 dictionary ConstrainDoubleRange : DoubleRange {
		double exact;
		double ideal;
	 };

	 // typedef (boolean or ConstrainBooleanParameters) ConstrainBoolean;
	 dictionary ConstrainBooleanParameters {
		boolean exact;
		boolean ideal;
	 };

	 // typedef (DOMString or sequence<DOMString> or ConstrainDOMStringParameters) ConstrainDOMString;
	 // We convert DOMString to ConstrainDOMStringParameters.exact
	 dictionary ConstrainDOMStringParameters {
		(DOMString or sequence<DOMString>) exact;
		(DOMString or sequence<DOMString>) ideal;
	 };
	*/

	// Get video constraints
	if (videoRequested) {
		// Todo : 
	}

	// Get audio constraints
	if (audioRequested) {

		// Handle object audio constraints
		newConstraints.audio = {};

		// Handle Stupid not up-to-date webrtc-adapter
		// Note: Firefox [38+] does support a subset of constraints with getUserMedia(), but not the outdated syntax that Chrome and Opera are using.
		// The mandatory / optional syntax was deprecated a in 2014, and minWidth and minHeight the year before that.
		if (
			typeof constraints.audio === 'object' &&
				(typeof constraints.audio.optional === 'object' || typeof constraints.audio.mandatory === 'object')
		) {
			if (
				typeof constraints.audio.optional === 'object'
			) {
				if (typeof constraints.audio.optional.sourceId === 'string') {
					newConstraints.audio.deviceId = {
						ideal: constraints.audio.optional.sourceId
					};
				} else if (
					Array.isArray(constraints.audio.optional) &&
						typeof constraints.audio.optional[0] === 'object' &&
							typeof constraints.audio.optional[0].sourceId === 'string'
				) {
					newConstraints.audio.deviceId = {
						ideal: constraints.audio.optional[0].sourceId
					};
				}
			} else if (
				constraints.audio.mandatory &&
					typeof constraints.audio.mandatory.sourceId === 'string'
			) {
				newConstraints.audio.deviceId = {
					exact: constraints.audio.mandatory.sourceId
				};
			}
		}

		// Get requested audio deviceId.
		if (typeof constraints.audio.deviceId === 'string') {
			newConstraints.audio.deviceId = {
				exact: constraints.audio.deviceId
			};

		// Also check audio sourceId (mangled by adapter.js).
		} else if (typeof constraints.audio.sourceId === 'string') {
			newConstraints.audio.deviceId = {
				exact: constraints.audio.sourceId
			};

		// Also check deviceId.(exact|ideal)
		} else if (typeof constraints.audio.deviceId === 'object') {
			if (!!constraints.audio.deviceId.exact) {
				newConstraints.audio.deviceId = {
					exact: Array.isArray(constraints.audio.deviceId.exact) ?
						constraints.audio.deviceId.exact[0] : constraints.audio.deviceId.exact
				};
			} else if (!!constraints.audio.deviceId.ideal) {
				newConstraints.audio.deviceId = {
					ideal: Array.isArray(constraints.audio.deviceId.ideal) ?
							constraints.audio.deviceId.ideal[0] : constraints.audio.deviceId.ideal
				};
			}
		}
	}

	debug('[computed constraints:%o]', newConstraints);

	return new Promise(function (resolve, reject) {
		function onResultOK(data) {
			debug('getUserMedia() | success');
			var stream = MediaStream.create(data.stream);
			resolve(stream);
			// Emit "connected" on the stream.
			stream.emitConnected();
		}

		function onResultError(error) {
			debugerror('getUserMedia() | failure: %s', error);
			reject(new Errors.MediaStreamError('getUserMedia() failed: ' + error));
		}

		exec.execNative(onResultOK, onResultError, 'WKWebViewRTC', 'getUserMedia', [newConstraints]);
	});
}
