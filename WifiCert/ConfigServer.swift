//
//  ConfigServer.swift
//  WifiCert
//
//  Created by Pavel Kozlov on 04/09/2019.
//  Copyright © 2019 Pavel Kozlov. All rights reserved.
//

import Foundation
import Swifter

class ConfigServer: NSObject {
    
    //TODO: Don't foget to add your custom app url scheme to info.plist if you have one!
    
    private enum ConfigState: Int
    {
        case Stopped, Ready, InstalledConfig, BackToApp
    }
    
    internal let listeningPort: Int = 8080
    internal var configName: String = "Profile install"
    private var localServer: HttpServer!
    private var returnURL: String!
    private var configData: Data!
    
    private var serverState: ConfigState = .Stopped
    private var startTime: Date!
    private var registeredForNotifications = false
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    
    deinit
    {
        unregisterFromNotifications()
    }
    
    init(configData: Data, returnURL: String)
    {
        super.init()
        self.returnURL = returnURL
        self.configData = configData
        localServer = HttpServer()
        self.setupHandlers()
    }
    
    //MARK:- Control functions
    
    internal func start() -> Bool
    {
        let page = self.baseURL(pathComponent: "start/")
        let url: URL = URL(string: page)!
        if UIApplication.shared.canOpenURL(url) {
            do {
                try localServer.start(in_port_t(listeningPort))
                
                startTime = Date()
                serverState = .Ready
                registerForNotifications()
                UIApplication.shared.open(url, options: [:]) { (success) in
                    print("success", success)
                }
                return true
                
            } catch {
                print("error", error)
                self.stop()
            }
        }
        return false
    }
    
    internal func stop()
    {
        if serverState != .Stopped {
            serverState = .Stopped
            unregisterFromNotifications()
        }
    }
    
    //MARK:- Private functions
    
    private func setupHandlers()
    {
        localServer["/start"] = { request in
            if self.serverState == .Ready {
                let page = self.basePage(pathComponent: "install/")
                return .ok(.htmlBody(page))
            } else {
                return .notFound
            }
        }
        localServer["/install"] = { request in
            switch self.serverState {
            case .Stopped:
                return .notFound
            case .Ready:
                self.serverState = .InstalledConfig
                return HttpResponse.raw(200, "OK", ["Content-Type": "application/x-apple-aspen-config"], { (writer) in
                    do {
                        try writer.write(self.configData!)
                    } catch {
                        print("error writer", error)
                    }
                })
            case .InstalledConfig:
                return .movedPermanently(self.returnURL)
            case .BackToApp:
                let page = self.basePage(pathComponent: nil)
                return .ok(.htmlBody(page))
            }
        }
    }
    
    private func baseURL(pathComponent: String?) -> String
    {
        var page = "http://localhost:\(listeningPort)"
        if let component = pathComponent {
            page += "/\(component)"
        }
        return page
    }
    
    private func basePage(pathComponent: String?) -> String
    {
        var page = "<!doctype html><html>" + "<head><meta charset='utf-8'><title>\(configName))</title></head>"
        if let component = pathComponent {
            let script = "function load() { window.location.href='\(self.baseURL(pathComponent: component))'; }window.setInterval(load, 600);"
            page += "<script>\(script)</script>"
        }
        page += "<body></body></html>"
        return page
    }
    
    private func returnedToApp() {
        if serverState != .Stopped {
            serverState = .BackToApp
            localServer.stop()
        }
        // Do whatever else you need to to
    }
    
    private func registerForNotifications() {
        if !registeredForNotifications {
            let notificationCenter = NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(didEnterBackground(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(willEnterForeground(notification:)), name: UIApplication.willEnterForegroundNotification, object: nil)
            registeredForNotifications = true
        }
    }
    
    private func unregisterFromNotifications() {
        if registeredForNotifications {
            let notificationCenter = NotificationCenter.default
            notificationCenter.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
            notificationCenter.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
            registeredForNotifications = false
        }
    }
    
    @objc internal func didEnterBackground(notification: NSNotification) {
        if serverState != .Stopped {
            startBackgroundTask()
        }
    }
    
    @objc internal func willEnterForeground(notification: NSNotification) {
        if backgroundTask != UIBackgroundTaskIdentifier.invalid {
            stopBackgroundTask()
            returnedToApp()
        }
    }
    
    private func startBackgroundTask() {
        let application = UIApplication.shared
        backgroundTask = application.beginBackgroundTask() {
            DispatchQueue.main.async {
                self.stopBackgroundTask()
            }
        }
    }
    
    private func stopBackgroundTask() {
        if backgroundTask != UIBackgroundTaskIdentifier.invalid {
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            backgroundTask = UIBackgroundTaskIdentifier.invalid
        }
    }
}
