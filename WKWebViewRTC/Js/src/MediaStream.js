/*
 * cordova-plugin-iosrtc v6.0.12
 * Cordova iOS plugin exposing the ̶f̶u̶l̶l̶ WebRTC W3C JavaScript APIs.
 * Copyright 2015-2017 eFace2Face, Inc. (https://eface2face.com)
 * Copyright 2015-2019 BasqueVoIPMafia (https://github.com/BasqueVoIPMafia)
 * Copyright 2019 Cordova-RTC (https://github.com/cordova-rtc)
 * The MIT License (MIT)
 */

/**
 * Expose the MediaStream class.
 */
module.exports = MediaStream;

/**
 * Spec: http://w3c.github.io/mediacapture-main/#mediastream
 */

/**
 * Dependencies.
 */
var
	debug = require('debug')('iosrtc:MediaStream'),
	exec = require('./IOSExec'),
	EventTarget = require('./EventTarget'),
	MediaStreamTrack = require('./MediaStreamTrack'),

/**
 * Local variables.
 */

	// Dictionary of MediaStreams (provided via getMediaStreams() class method).
	// - key: MediaStream blobId.
	// - value: MediaStream.
	mediaStreams;

// TODO longer UUID like native call
// - "4021904575-2849079001-3048689102-1644344044-4021904575-2849079001-3048689102-1644344044"
function newMediaStreamId() {
   return window.crypto.getRandomValues(new Uint32Array(4)).join('-');
}

// Save original MediaStream
var originalMediaStream = window.MediaStream || window.Blob;
//var originalMediaStream = window.Blob;
var originalMediaStreamTrack = MediaStreamTrack.originalMediaStreamTrack;

/**
 * Expose the MediaStream class.
 */
function MediaStream(arg, id) {
	debug('new MediaStream(arg) | [arg:%o]', arg);

	// Detect native MediaStream usage
	// new MediaStream(originalMediaStream) // stream
	// new MediaStream(originalMediaStreamTrack[]) // tracks
	if (
		!(arg instanceof window.Blob) &&
			(arg instanceof originalMediaStream && typeof arg.getBlobId === 'undefined') ||
				(Array.isArray(arg) && arg[0] instanceof originalMediaStreamTrack)
	) {
		return new originalMediaStream(arg);
	}

	// new MediaStream(MediaStream) // stream
	// new MediaStream(MediaStreamTrack[]) // tracks
	// new MediaStream() // empty

	id = id || newMediaStreamId();
	var blobId = 'MediaStream_' + id;

	// Extend returned MediaTream with custom MediaStream
	var stream;
	if (originalMediaStream !== window.Blob) {
		stream = new (Function.prototype.bind.apply(originalMediaStream.bind(this), [])); // jshint ignore:line

	// Fallback on Blob if originalMediaStream is not a MediaStream and Emulate EventTarget
	} else {
		stream = new Blob([blobId], {
			type: 'stream'
		});

		var target = document.createTextNode(null);
		stream.addEventListener = target.addEventListener.bind(target);
		stream.removeEventListener = target.removeEventListener.bind(target);
		stream.dispatchEvent = target.dispatchEvent.bind(target);
	}

	Object.defineProperties(stream, Object.getOwnPropertyDescriptors(MediaStream.prototype));

	// Make it an EventTarget.
	EventTarget.call(stream);

	// Public atributes.
	stream._id = id || newMediaStreamId();
	stream._active = true;

	// Init Stream by Id
	exec.execNative(null, null, 'WKWebViewRTC', 'MediaStream_init', [stream.id]);

	// Public but internal attributes.
	stream.connected = false;

	// Private attributes.
	stream._audioTracks = {};
	stream._videoTracks = {};

	// Store the stream into the dictionary.
	stream._blobId = blobId;
	mediaStreams[stream._blobId] = stream;

	// Convert arg to array of tracks if possible
	if (
		(arg instanceof MediaStream) ||
			(arg instanceof MediaStream.originalMediaStream)
	) {
		arg = arg.getTracks();
	}

	if (Array.isArray(arg)) {
		arg.forEach(function (track) {
			stream.addTrack(track);
		});
	} else if (typeof arg !== 'undefined') {
		throw new TypeError("Failed to construct 'MediaStream': No matching constructor signature.");
	}

	function onResultOK(data) {
		onEvent.call(stream, data);
	}
	exec.execNative(onResultOK, null, 'WKWebViewRTC', 'MediaStream_setListener', [stream.id]);

	return stream;
}

MediaStream.prototype = Object.create(originalMediaStream.prototype, {
	id: {
		get: function () {
			return this._id;
		}
	},
	active: {
		get: function () {
			return this._active;
		}
	},
	// Backwards compatibility.
	label: {
		get: function () {
			return this._id;
		}
	}
});

Object.defineProperties(MediaStream.prototype, Object.getOwnPropertyDescriptors(EventTarget.prototype));

MediaStream.prototype.constructor = MediaStream;

// Static reference to original MediaStream
MediaStream.originalMediaStream = originalMediaStream;

/**
 * Class methods.
 */

MediaStream.setMediaStreams = function (_mediaStreams) {
	mediaStreams = _mediaStreams;
};

MediaStream.getMediaStreams = function () {
	return mediaStreams;
};

MediaStream.create = function (dataFromEvent) {
	debug('create() | [dataFromEvent:%o]', dataFromEvent);

	var trackId, track,
		stream = new MediaStream([], dataFromEvent.id);

	// We do not use addTrack to prevent false positive "ERROR: video track not added" and "ERROR: audio track not added"
	// cause the rtcMediaStream already has them internaly.

	for (trackId in dataFromEvent.audioTracks) {
		if (dataFromEvent.audioTracks.hasOwnProperty(trackId)) {
			track = new MediaStreamTrack(dataFromEvent.audioTracks[trackId]);

			stream._audioTracks[track.id] = track;

			addListenerForTrackEnded.call(stream, track);
		}
	}

	// Todo :

	return stream;
};

MediaStream.prototype.getBlobId = function () {
	return this._blobId;
};

MediaStream.prototype.getAudioTracks = function () {
	debug('getAudioTracks()');

	var tracks = [],
		id;

	for (id in this._audioTracks) {
		if (this._audioTracks.hasOwnProperty(id)) {
			tracks.push(this._audioTracks[id]);
		}
	}

	return tracks;
};


MediaStream.prototype.getVideoTracks = function () {
	debug('getVideoTracks()');

	// Todo :
	
	return [];
};


MediaStream.prototype.getTracks = function () {
	debug('getTracks()');

	var tracks = [],
		id;

	for (id in this._audioTracks) {
		if (this._audioTracks.hasOwnProperty(id)) {
			tracks.push(this._audioTracks[id]);
		}
	}

	// Todo :

	return tracks;
};


MediaStream.prototype.getTrackById = function (id) {
	debug('getTrackById()');

	return this._audioTracks[id] || this._videoTracks[id] || null;
};

MediaStream.prototype.addTrack = function (track) {
	debug('addTrack() [track:%o]', track);

	if (!(track instanceof MediaStreamTrack)) {
		throw new Error('argument must be an instance of MediaStreamTrack');
	}

	if (this._audioTracks[track.id] || this._videoTracks[track.id]) {
		return;
	}

	if (track.kind === 'audio') {
		this._audioTracks[track.id] = track;
	} else if (track.kind === 'video') {
		// Todo :
	} else {
		throw new Error('unknown kind attribute: ' + track.kind);
	}

	addListenerForTrackEnded.call(this, track);

	exec.execNative(null, null, 'WKWebViewRTC', 'MediaStream_addTrack', [this.id, track.id]);

	this.dispatchEvent(new Event('update'));

	this.emitConnected();
};

MediaStream.prototype.removeTrack = function (track) {
	debug('removeTrack() [track:%o]', track);

	if (!(track instanceof MediaStreamTrack)) {
		throw new Error('argument must be an instance of MediaStreamTrack');
	}

	if (!this._audioTracks[track.id] && !this._videoTracks[track.id]) {
		return;
	}

	if (track.kind === 'audio') {
		delete this._audioTracks[track.id];
	} else if (track.kind === 'video') {
		// Todo :
	} else {
		throw new Error('unknown kind attribute: ' + track.kind);
	}

	exec.execNative(null, null, 'WKWebViewRTC', 'MediaStream_removeTrack', [this.id, track.id]);

	this.dispatchEvent(new Event('update'));

	checkActive.call(this);
};


MediaStream.prototype.clone = function () {
	debug('clone()');
	return new MediaStream(this);
};

// Backwards compatible API.
MediaStream.prototype.stop = function () {
	debug('stop()');

	var trackId;

	for (trackId in this._audioTracks) {
		if (this._audioTracks.hasOwnProperty(trackId)) {
			this._audioTracks[trackId].stop();
		}
	}

	// Todo :
};


// TODO: API methods and events.


/**
 * Private API.
 */


MediaStream.prototype.emitConnected = function () {
	debug('emitConnected()');

	var self = this;

	if (this.connected) {
		return;
	}
	this.connected = true;

	setTimeout(function (self) {
		var event = new Event('connected');
		Object.defineProperty(event, 'target', {value: self, enumerable: true});
		self.dispatchEvent(event);
	}, 0, self);
};


function addListenerForTrackEnded(track) {
	var self = this;

	track.addEventListener('ended', function () {
		if (track.kind === 'audio' && !self._audioTracks[track.id]) {
			return;
		} else if (track.kind === 'video' && !self._videoTracks[track.id]) {
			return;
		}

		checkActive.call(self);
	});
}


function checkActive() {
	// A MediaStream object is said to be active when it has at least one MediaStreamTrack
	// that has not ended. A MediaStream that does not have any tracks or only has tracks
	// that are ended is inactive.

	var self = this,
		trackId;

	if (!this.active) {
		return;
	}

	if (Object.keys(this._audioTracks).length === 0 && Object.keys(this._videoTracks).length === 0) {
		debug('no tracks, releasing MediaStream');

		release();
		return;
	}

	for (trackId in this._audioTracks) {
		if (this._audioTracks.hasOwnProperty(trackId)) {
			if (this._audioTracks[trackId].readyState !== 'ended') {
				return;
			}
		}
	}

	// Todo :

	debug('all tracks are ended, releasing MediaStream');
	release();

	function release() {
		self._active = false;
		self.dispatchEvent(new Event('inactive'));

		// Remove the stream from the dictionary.
		delete mediaStreams[self._blobId];

		exec.execNative(null, null, 'WKWebViewRTC', 'MediaStream_release', [self.id]);
	}
}


function onEvent(data) {
	var type = data.type,
		event,
		track;

	debug('onEvent() | [type:%s, data:%o]', type, data);

	switch (type) {
		case 'addtrack':
			track = new MediaStreamTrack(data.track);

			if (track.kind === 'audio') {
				this._audioTracks[track.id] = track;
			} else if (track.kind === 'video') {
				// Todo :
			}
			addListenerForTrackEnded.call(this, track);

			event = new Event('addtrack');
			event.track = track;

			this.dispatchEvent(event);

			// Also emit 'update' for the MediaStreamRenderer.
			this.dispatchEvent(new Event('update'));
			break;

		case 'removetrack':
			if (data.track.kind === 'audio') {
				track = this._audioTracks[data.track.id];
				delete this._audioTracks[data.track.id];
			} else if (data.track.kind === 'video') {
				// Todo :
			}

			if (!track) {
				throw new Error('"removetrack" event fired on MediaStream for a non existing MediaStreamTrack');
			}

			event = new Event('removetrack');
			event.track = track;

			this.dispatchEvent(event);

			// Check whether the MediaStream still is active.
			checkActive.call(this);
			break;
	}
}
