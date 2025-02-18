//
//  SynxApp.swift
//  Synx
//
//  Created by Shawn on 10/13/24.
//

import SwiftUI


//@main
//struct SynxApp: App {
//    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
//    var body: some Scene {
//        WindowGroup {
//            LoginView()
//        }
//    }
//}

//
//  SynxApp.swift
//  Synx
//
//  Created by Shawn on 10/13/24.
//

import SwiftUI
import UIKit
import Firebase
import GoogleSignIn
import UserNotifications
import FirebaseAuth


@main
struct AuroraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            LoginView()
                .preferredColorScheme(.light)
        }
    }
}


import UIKit
import Firebase
import FirebaseMessaging
import FirebaseAuth
import UserNotifications
import GoogleSignIn

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    private let firebaseManager = FirebaseManager.shared
    
    private var backgroundObserver: NSObjectProtocol?
        private var foregroundObserver: NSObjectProtocol?
    
    // Firebase AppDelegate
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("AppDelegate: Application did finish launching.")
        
        // Ensure FirebaseApp is only configured once
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Messaging delegate setup
        Messaging.messaging().delegate = self
        
        // Notification center delegate setup
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        addAppLifecycleObservers()
        
        return true
    }
    
    private func addAppLifecycleObservers() {
            // Save references to the observers
            self.backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main) { [weak self] _ in
                    self?.appWentToBackground()
            }
            
            self.foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main) { [weak self] _ in
                    self?.appCameToForeground()
            }
        }
        
        private func appWentToBackground() {
            print("App went to background")
        }
        
        private func appCameToForeground() {
            print("App came to foreground")
            resetBadge()
        }
        
    private func resetBadge() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users")
            .document(userId)
            .getDocument { [weak self] (document, error) in
                if let error = error {
                    print("Error getting user document: \(error)")
                    return
                }
                
                if let document = document, document.exists {
                    let hasPosted = document.data()?["hasPosted"] as? Bool ?? false
                    
                    DispatchQueue.main.async {
                        print("Setting badge based on hasposted: \(hasPosted)")
                        UIApplication.shared.applicationIconBadgeNumber = hasPosted ? 0 : 1
                        
                        // Update badge count in Firestore
                        db.collection("users").document(userId).updateData([
                            "badgeCount": hasPosted ? 0 : 1
                        ]) { error in
                            if let error = error {
                                print("Error updating badge count: \(error)")
                            } else {
                                print("Successfully updated badge count in Firestore")
                            }
                        }
                    }
                }
            }
    }
        
        // Remove observers when app is terminated
        deinit {
            if let backgroundObserver = backgroundObserver {
                NotificationCenter.default.removeObserver(backgroundObserver)
            }
            if let foregroundObserver = foregroundObserver {
                NotificationCenter.default.removeObserver(foregroundObserver)
            }
        }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                  willPresent notification: UNNotification,
                                  withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            let userInfo = notification.request.content.userInfo
            
            if let aps = userInfo["aps"] as? [String: Any],
               let badge = aps["badge"] as? Int {
                DispatchQueue.main.async {
                    UIApplication.shared.applicationIconBadgeNumber = badge
                }
            }
            
            completionHandler([[.badge, .sound, .banner]])
        }
        
        func application(_ application: UIApplication,
                         didReceiveRemoteNotification notification: [AnyHashable: Any],
                         fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
            print("AppDelegate: Received remote notification.")
            
            if let aps = notification["aps"] as? [String: Any],
               let badge = aps["badge"] as? Int {
                DispatchQueue.main.async {
                    UIApplication.shared.applicationIconBadgeNumber = badge
                }
            }
            
            if firebaseManager.auth.canHandleNotification(notification) {
                completionHandler(.noData)
                return
            }
            completionHandler(.newData)
        }

        // When app becomes active, reset badge in both UI and Firestore
        func applicationDidBecomeActive(_ application: UIApplication) {
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = 0
                
                // Reset badge count in Firestore
                if let userId = Auth.auth().currentUser?.uid {
                    Firestore.firestore().collection("users").document(userId).updateData([
                        "badgeCount": 0
                    ]) { error in
                        if let error = error {
                            print("Error resetting badge count: \(error)")
                        }
                    }
                }
            }
        }
    
    
    // Phone Verification
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("AppDelegate: Registered for remote notifications.")
        
        // Set APNs token for Firebase Authentication
        firebaseManager.auth.setAPNSToken(deviceToken, type: .sandbox)
        
        // Set APNs token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        print("AppDelegate: APNs token set for Firebase Messaging.")
    }
    
    // Google Sign-In AppDelegate
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print("AppDelegate: Handling Google Sign-In URL.")
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Received new FCM token: \(fcmToken ?? "No Token")")
    }
    
}


