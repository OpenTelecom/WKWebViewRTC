//
//  ViewController.swift
//  WKWebViewRTC.Sample
//
//  Created by Open Telecom Foundation on 2020/7/6.
//  Copyright © 2020 Open Telecom Foundation. All rights reserved.
//  The MIT License (MIT)
//

import UIKit
import WebKit
import WKWebViewRTC

class ViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Do any additional setup after loading the view.
		let configuration = WKWebViewConfiguration()
		let controller = WKUserContentController()
		configuration.userContentController = controller
		
		let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
		
		WKWebViewRTC(wkwebview: webView, contentController: controller)
		
		webView.load(URLRequest(url: URL(string: "https://sip-phone-test.reper.io/?name=Display%20Name&websocket=wss://domain.com:5065&sipuri=sip_user@domain.com&password=password")!))
		
		super.loadView()
		view.addSubview(webView)
		webView.frame = view.frame
	}
}

