# WKWebViewRTC

[![CI Status](https://img.shields.io/travis/JustDoIt9/WKWebViewRTC.svg?style=flat)](https://travis-ci.org/JustDoIt9/WKWebViewRTC)
[![Version](https://img.shields.io/cocoapods/v/WKWebViewRTC.svg?style=flat)](https://cocoapods.org/pods/WKWebViewRTC)
[![License](https://img.shields.io/cocoapods/l/WKWebViewRTC.svg?style=flat)](https://cocoapods.org/pods/WKWebViewRTC)
[![Platform](https://img.shields.io/cocoapods/p/WKWebViewRTC.svg?style=flat)](https://cocoapods.org/pods/WKWebViewRTC)

WebRTC library for WKWebView for Swift on iOS (based on cordova-plugin-iosrtc: https://github.com/cordova-rtc/cordova-plugin-iosrtc)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

In order to make this framework run into a iOS application some requirements must be satisfied in both development computer and target devices:

* Xcode >= 11.1 (11A1027)
* iOS >= 10.2 (run on lower versions at your own risk, don't report issues)
* `swift-version` => 4.2

## Installation

WKWebViewRTC is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'WKWebViewRTC'
```

## Dependencies
 * [GoogleWebRTC](https://cocoapods.org/pods/GoogleWebRTC) => v1.1.29229

## Build JS (WKWebViewRTC/Js/jsWKWebViewRTC.js)

* From the WKWebViewRTC/Js run `npm i` and then `npm run-script build`

### Third-Party Supported Library

* Janus => 0.7.4
* JSSip => 3.1.2
* Sip.js => 0.15.6

## Author

Open Telecom Foundation

## License

WKWebViewRTC is available under the MIT license. See the LICENSE file for more info.
