/*
 * cordova-plugin-iosrtc v6.0.17
 * Cordova iOS plugin exposing the ̶f̶u̶l̶l̶ WebRTC W3C JavaScript APIs.
 * Copyright 2015-2017 eFace2Face, Inc. (https://eface2face.com)
 * Copyright 2015-2019 BasqueVoIPMafia (https://github.com/BasqueVoIPMafia)
 * Copyright 2019 Cordova-RTC (https://github.com/cordova-rtc)
 * The MIT License (MIT)
 */

/**
 * Dependencies.
 */
var
	YaetiEventTarget = require('yaeti').EventTarget;

var EventTarget = function () {
	YaetiEventTarget.call(this);
};

EventTarget.prototype = Object.create(YaetiEventTarget.prototype);
EventTarget.prototype.constructor = EventTarget;

Object.defineProperties(EventTarget.prototype, Object.getOwnPropertyDescriptors(YaetiEventTarget.prototype));

EventTarget.prototype.dispatchEvent = function (event) {

	Object.defineProperty(event, 'target', {
	  value: this,
	  writable: false
	});

	YaetiEventTarget.prototype.dispatchEvent.call(this, event);
};

/**
 * Expose the EventTarget class.
 */
module.exports = EventTarget;
