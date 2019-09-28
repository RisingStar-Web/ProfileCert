//
//  ViewController.swift
//  WifiCert
//
//  Created by Pavel Kozlov on 04/09/2019.
//  Copyright © 2019 Pavel Kozlov. All rights reserved.
//

import UIKit
import NetworkExtension

class ViewController: UIViewController {
    
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    let wifiConfigLink = URL(string: "http://iurus.my/wificertificate.mobileconfig")!
    
    private var server: ConfigServer!
    
//    let username = "MUIDMTester"
//    let password = "Passw0rd"
    
    let usernameKey = "!!!UserName!!!"
    let passwordKey = "!!!UserPassword!!!"

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func open() {
        UIApplication.shared.open(wifiConfigLink, options: [:]) { (success) in
            print("success", success)
        }
    }
   
    @IBAction func install(_ sender: UIButton) {
        guard usernameField.text?.isEmpty == false, passwordField.text?.isEmpty == false else { return }
        
        do {
            let username = usernameField.text!
            let password = passwordField.text!
            
            let configDataUrl = Bundle.main.url(forResource: "wificertificate", withExtension: "mobileconfig")!
            
            var plistString = try String(contentsOf: configDataUrl)
            plistString = plistString.replacingOccurrences(of: usernameKey, with: username).replacingOccurrences(of: passwordKey, with: password)
            
            let configData = plistString.data(using: String.Encoding.utf8)!
            server = ConfigServer(configData: configData, returnURL: "WifiCert://")
            _ = server.start()
        } catch {
            print("error configData", error)
        }
    }
    
}

