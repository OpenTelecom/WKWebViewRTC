//
//  iosrtc.js
//  WKWebViewRTC
//
//  Created by Open Telecom Foundation on 2020/6/30.
//  Copyright © 2020 Open Telecom Foundation. All rights reserved.
//  The MIT License (MIT)
//

/**
 * Variables.
 */

var
	// Dictionary of MediaStreamRenderers.
	// - key: MediaStreamRenderer id.
	// - value: MediaStreamRenderer.
	mediaStreamRenderers = {},

	// Dictionary of MediaStreams.
	// - key: MediaStream blobId.
	// - value: MediaStream.
	mediaStreams = {},


/**
 * Dependencies.
 */
	debug                  = require('debug')('iosrtc'),
	exec                   = require('./IOSExec'),
	domready               = require('domready'),

	getUserMedia           = require('./getUserMedia'),
	enumerateDevices       = require('./enumerateDevices'),
	RTCPeerConnection      = require('./RTCPeerConnection'),
	RTCSessionDescription  = require('./RTCSessionDescription'),
	RTCIceCandidate        = require('./RTCIceCandidate'),
	MediaDevices           = require('./MediaDevices'),
	MediaStream            = require('./MediaStream'),
	MediaStreamTrack       = require('./MediaStreamTrack'),
	videoElementsHandler   = require('./videoElementsHandler');


/**
 * Expose the iosrtc object.
 */
module.exports = {
	// Expose WebRTC classes and functions.
	getUserMedia:          getUserMedia,
	enumerateDevices:      enumerateDevices,
	getMediaDevices:       enumerateDevices,  // TMP
	RTCPeerConnection:     RTCPeerConnection,
	RTCSessionDescription: RTCSessionDescription,
	RTCIceCandidate:       RTCIceCandidate,
	MediaDevices:          MediaDevices,
	MediaStream:           MediaStream,
	MediaStreamTrack:      MediaStreamTrack,

	// Expose a function to refresh current videos rendering a MediaStream.
	refreshVideos:         videoElementsHandler.refreshVideos,

	// Expose a function to handle a video not yet inserted in the DOM.
	observeVideo:          videoElementsHandler.observeVideo,

	// Select audio output (earpiece or speaker).
	selectAudioOutput:     selectAudioOutput,

	// turnOnSpeaker with options
	turnOnSpeaker: turnOnSpeaker,

	// Checking permision (audio and camera)
	requestPermission: requestPermission,

	// Expose a function to initAudioDevices if needed, sets the audio session active
	initAudioDevices: initAudioDevices,

	// Expose a function to pollute window and naigator namespaces.
	registerGlobals:       registerGlobals,

	// Expose the debug module.
	debug:                 require('debug'),

	// Debug function to see what happens internally.
	dump:                  dump,

	// Debug Stores to see what happens internally.
	mediaStreamRenderers:  mediaStreamRenderers,
	mediaStreams:          mediaStreams,
	nativeCallback:		   exec.nativeCallback
};
registerGlobals();
initAudioDevices();
turnOnSpeaker(true);
requestPermission(true, true, function (result) {
	console.log('requestPermission.result', result);
	});

domready(function () {
	// Let the MediaStream class and the videoElementsHandler share same MediaStreams container.
	MediaStream.setMediaStreams(mediaStreams);
	videoElementsHandler(mediaStreams, mediaStreamRenderers);

	// refreshVideos on device orientation change to resize peers video
	// while local video will resize du orientation change
	window.addEventListener('resize', function () {
		videoElementsHandler.refreshVideos();
	});
});

function selectAudioOutput(output) {
	debug('selectAudioOutput() | [output:"%s"]', output);

	switch (output) {
		case 'earpiece':
			exec.execNative(null, null, 'WKWebViewRTC', 'selectAudioOutputEarpiece', []);
			break;
		case 'speaker':
			exec.execNative(null, null, 'WKWebViewRTC', 'selectAudioOutputSpeaker', []);
			break;
		default:
			throw new Error('output must be "earpiece" or "speaker"');
	}
}

function turnOnSpeaker(isTurnOn) {
	debug('turnOnSpeaker() | [isTurnOn:"%s"]', isTurnOn);

	exec.execNative(null, null, 'WKWebViewRTC', "RTCTurnOnSpeaker", [isTurnOn]);
}

function requestPermission(needMic, needCamera, callback) {
	debug('requestPermission() | [needMic:"%s", needCamera:"%s"]', needMic, needCamera);

	function ok() {
		callback(true);
	}

	function error() {
		callback(false);
	}
	exec.execNative(ok, error, 'WKWebViewRTC', "RTCRequestPermission", [needMic, needCamera]);
}

function initAudioDevices() {
	debug('initAudioDevices()');

	exec.execNative(null, null, 'WKWebViewRTC', "initAudioDevices", []);
}

function callbackifyMethod(originalMethod) {
	return function (arg) { // jshint ignore:line
		var success, failure,
		  originalArgs = Array.prototype.slice.call(arguments);

		var callbackArgs = [];
		originalArgs.forEach(function (arg) {
			if (typeof arg === 'function') {
				if (!success) {
					success = arg;
				} else {
					failure = arg;
				}
			} else {
				callbackArgs.push(arg);
			}
		});

		var promiseResult = originalMethod.apply(this, callbackArgs);

		// Only apply then if callback success available
		if (typeof success === 'function') {
			promiseResult = promiseResult.then(success);
		}

		// Only apply catch if callback failure available
		if (typeof failure === 'function') {
			promiseResult = promiseResult.catch(failure);
		}

		return promiseResult;
	};
}

function callbackifyPrototype(proto, method) {
	var originalMethod = proto[method];
	proto[method] = callbackifyMethod(originalMethod);
}

function restoreCallbacksSupport() {
	debug('restoreCallbacksSupport()');
	getUserMedia = callbackifyMethod(getUserMedia);
	enumerateDevices = callbackifyMethod(enumerateDevices);
	callbackifyPrototype(RTCPeerConnection.prototype, 'createAnswer');
	callbackifyPrototype(RTCPeerConnection.prototype, 'createOffer');
	callbackifyPrototype(RTCPeerConnection.prototype, 'setRemoteDescription');
	callbackifyPrototype(RTCPeerConnection.prototype, 'setLocalDescription');
	callbackifyPrototype(RTCPeerConnection.prototype, 'addIceCandidate');
	callbackifyPrototype(RTCPeerConnection.prototype, 'getStats');
}

function registerGlobals(doNotRestoreCallbacksSupport) {
	debug('registerGlobals()');

	if (!global.navigator) {
		global.navigator = {};
	}

	if (!navigator.mediaDevices) {
		navigator.mediaDevices = new MediaDevices();
	}

	// Restore Callback support
	if (!doNotRestoreCallbacksSupport) {
		restoreCallbacksSupport();
	}

	navigator.getUserMedia                  = getUserMedia;
	navigator.webkitGetUserMedia            = getUserMedia;
	navigator.mediaDevices.getUserMedia     = getUserMedia;
	navigator.mediaDevices.enumerateDevices = enumerateDevices;

	window.RTCPeerConnection                = RTCPeerConnection;
	window.webkitRTCPeerConnection          = RTCPeerConnection;
	window.RTCSessionDescription            = RTCSessionDescription;
	window.RTCIceCandidate                  = RTCIceCandidate;
	window.MediaStream                      = MediaStream;
	window.webkitMediaStream                = MediaStream;
	window.MediaStreamTrack                 = MediaStreamTrack;

	// Apply CanvasRenderingContext2D.drawImage monkey patch
	var drawImage = CanvasRenderingContext2D.prototype.drawImage;
	CanvasRenderingContext2D.prototype.drawImage = function (arg) {
		var args = Array.prototype.slice.call(arguments);
		var context = this;
		if (arg instanceof HTMLVideoElement && arg.render) {
			arg.render.save(function (data) {
			    var img = new window.Image();
			    img.addEventListener("load", function () {
			    	args.splice(0, 1, img.src);
			        drawImage.apply(context, args);
			    });
			    img.setAttribute("src", "data:image/jpg;base64," + data);
		  	});
		} else {
			return drawImage.apply(context, args);
		}
	};
}

function dump() {
	exec.execNative(null, null, 'WKWebViewRTC', 'dump', []);
}
