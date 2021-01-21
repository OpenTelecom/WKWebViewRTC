/*
* cordova-plugin-iosrtc v6.0.17
* Cordova iOS plugin exposing the ̶f̶u̶l̶l̶ WebRTC W3C JavaScript APIs.
* Copyright 2015-2017 eFace2Face, Inc. (https://eface2face.com)
* Copyright 2015-2019 BasqueVoIPMafia (https://github.com/BasqueVoIPMafia)
* Copyright 2019 Cordova-RTC (https://github.com/cordova-rtc)
* The MIT License (MIT)
*/

import Foundation
import AVFoundation
import WebRTC

class iRTCAudioController {
	
	static private var audioCategory : AVAudioSession.Category = AVAudioSession.Category.playAndRecord

	static private var audioCategoryOptions : AVAudioSession.CategoryOptions = [
		AVAudioSession.CategoryOptions.mixWithOthers,
		AVAudioSession.CategoryOptions.allowBluetooth,
		AVAudioSession.CategoryOptions.allowAirPlay,
		AVAudioSession.CategoryOptions.allowBluetoothA2DP
	]

	/*
	 This mode is intended for Voice over IP (VoIP) apps and can only be used with the playAndRecord category. When this mode is used, the device’s tonal equalization is optimized for voice and the set of allowable audio routes is reduced to only those appropriate for voice chat.

	  See: https://developer.apple.com/documentation/avfoundation/avaudiosession/mode/1616455-voicechat
	 */
	static private var audioMode = AVAudioSession.Mode.voiceChat
	static private var audioModeDefault : AVAudioSession.Mode = AVAudioSession.Mode.default

	static private var audioInputSelected: AVAudioSessionPortDescription? = nil
	
	//
	// Audio Input
	//
	
	static func initAudioDevices() -> Void {
		
		iRTCAudioController.setCategory()
		
		do {
			let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
			try audioSession.setActive(true)
		} catch  {
			print("Error messing with audio session: \(error)")
		}
	}
	
	static func setCategory() -> Void {
		// Enable speaker
		NSLog("iRTCAudioController#setCategory()")
		
		do {
			let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
			try audioSession.setCategory(
				iRTCAudioController.audioCategory,
				mode: iRTCAudioController.audioMode,
				options: iRTCAudioController.audioCategoryOptions
			)
		} catch {
			NSLog("iRTCAudioController#setCategory() | ERROR \(error)")
		};
	}
	
	// Setter function inserted by save specific audio device
	static func saveInputAudioDevice(inputDeviceUID: String) -> Void {
		let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
		if let audioInput: AVAudioSessionPortDescription = audioSession.availableInputs!.first(where: { $0.uid == inputDeviceUID }) {
			iRTCAudioController.audioInputSelected = audioInput
		} else {
			NSLog("iRTCAudioController#saveInputAudioDevice() | ERROR invalid deviceId \(inputDeviceUID)")
			iRTCAudioController.audioInputSelected = audioSession.availableInputs!.first
		}
	}
	
	// Setter function inserted by set specific audio device
	static func restoreInputOutputAudioDevice() -> Void {
		let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
		
		do {
			try audioSession.setPreferredInput(iRTCAudioController.audioInputSelected)
		} catch {
			NSLog("iRTCAudioController:restoreInputOutputAudioDevice: Error setting audioSession preferred input.")
		}
		
		iRTCAudioController.setOutputSpeakerIfNeed(enabled: speakerEnabled);
	}
	
	static func setOutputSpeakerIfNeed(enabled: Bool) {
		
		speakerEnabled = enabled
		
		let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
		let currentRoute = audioSession.currentRoute
		
		if currentRoute.outputs.count != 0 {
			for description in currentRoute.outputs {
				if (
					description.portType == AVAudioSession.Port.headphones ||
						description.portType == AVAudioSession.Port.bluetoothA2DP ||
							description.portType == AVAudioSession.Port.carAudio ||
								description.portType == AVAudioSession.Port.airPlay ||
									description.portType == AVAudioSession.Port.lineOut
				) {
					NSLog("iRTCAudioController#setOutputSpeakerIfNeed() | external audio output plugged in -> do nothing")
				} else {
					NSLog("iRTCAudioController#setOutputSpeakerIfNeed() | external audio pulled out")
					
					if (speakerEnabled) {
						do {
							try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
						} catch {
							NSLog("iRTCAudioController#setOutputSpeakerIfNeed() | ERROR \(error)")
						};
					}
				}
			}
		} else {
			NSLog("iRTCAudioController#setOutputSpeakerIfNeed() | requires connection to device")
		}
	}
	
	static func selectAudioOutputSpeaker() {
		// Enable speaker
		NSLog("iRTCAudioController#selectAudioOutputSpeaker()")
		
		speakerEnabled = true;
		
		setCategory()
		
		do {
			let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
			try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
		} catch {
			NSLog("iRTCAudioController#selectAudioOutputSpeaker() | ERROR \(error)")
		};
	}
	
	static func selectAudioOutputEarpiece() {
		// Disable speaker, switched to default
		NSLog("iRTCAudioController#selectAudioOutputEarpiece()")
		
		speakerEnabled = false;
		
		setCategory()
		
		do {
			let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
			try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.none)
		} catch {
			NSLog("iRTCAudioController#selectAudioOutputEarpiece() | ERROR \(error)")
		};
	}

	//
	// Audio Output
	//
	
	static private var speakerEnabled: Bool = false
	
	init() {
        let shouldManualInit = Bundle.main.object(forInfoDictionaryKey: "ManualInitAudioDevice") as? String
    
        if(shouldManualInit == "FALSE") {
            iRTCAudioController.initAudioDevices()
        }
		
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(self.audioRouteChangeListener(_:)),
			name: AVAudioSession.routeChangeNotification,
			object: nil)
	}
	
	@objc dynamic fileprivate func audioRouteChangeListener(_ notification:Notification) {
		let audioRouteChangeReason = notification.userInfo![AVAudioSessionRouteChangeReasonKey] as! UInt
		
		switch audioRouteChangeReason {
		case AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue:
			NSLog("iRTCAudioController#audioRouteChangeListener() | headphone plugged in")
		case AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue:
			NSLog("iRTCAudioController#audioRouteChangeListener() | headphone pulled out -> restore state speakerEnabled: %@", iRTCAudioController.speakerEnabled ? "true" : "false")
			iRTCAudioController.setOutputSpeakerIfNeed(enabled: iRTCAudioController.speakerEnabled)
		default:
			break
		}
	}
}
