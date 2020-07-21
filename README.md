# WKWebViewRTC
WebRTC library for WKWebView for Swift on iOS (based on cordova-plugin-iosrtc)
WebRTC iOS framework is M69 from: https://github.com/cordova-rtc/cordova-plugin-iosrtc/commit/77edf7e3325ebb4fb43e0d3f697d41f2e30bdc51


## Requirements

In order to make this framework run into a iOS application some requirements must be satisfied in both development computer and target devices:

* Xcode >= 11.1 (11A1027)
* iOS >= 10.2 (run on lower versions at your own risk, don't report issues)
* `swift-version` => 4.2

## Build JS (WKWebViewRTC/Js/jsWKWebViewRTC.js)

* From the WKWebViewRTC/Js run `npm i` and then `npm run-scipt build`

### Third-Party Supported Library

* WebRTC W3C v1.0.0
* WebRTC.framework => M69
* Janus => 0.7.4
* JSSip => 3.1.2
* Sip.js => 0.15.6

# Sample Application

/KWebViewRTC.Sample is a sample project of this framework.

## License

[MIT](./LICENSE) :)
