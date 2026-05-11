//
//  AppDelegate.swift
//  identeam
//
//  Created by Nico Stern on 09.12.25.
//

import SwiftUI
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate,
    UNUserNotificationCenterDelegate
{
    @AppStorage("deviceToken") var deviceToken: String = ""
    @AppStorage("sessionToken") private var sessionToken: String = ""

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // all notification center events shall be forwarded to this object:
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [
            .alert, .sound, .badge,
        ]) { success, _ in  // err should not occur
            guard success else {
                return
            }

            print("Success in API registry")
        }

        application.registerForRemoteNotifications()

        return true
    }

    // Registration success
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }
            .joined()

        print("Device Token:", tokenString)
        self.deviceToken = tokenString  // saved in UserDefaults
    }

    // Registration fail
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register:", error)
    }
}
