//
//  NotificationController.swift
//  Qorvo NI Sample
//
//  Created by Carlos Silva on 24/11/2022.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation
import UserNotifications

class NotificationManager {
    
    static let instance = NotificationManager()
    
    func requestAuthorization() {
//        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
            (granted, error) in guard granted else { return }

            //DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }
    
    func setNotification(deviceName: String, deviceMessage: String) {
        let content = UNMutableNotificationContent()
        AccessoryDemoViewController.mqtt.connect()
        content.title = "Qorvo Device \(deviceName)"
        content.subtitle = "\(deviceMessage)"
        content.sound = .default
        AccessoryDemoViewController.mqtt.publish(topic: "moj/top", message: deviceMessage)

        //let trigger = UNNotificationTrigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(identifier: "Qorvo Nearby Interaction",
                                            content: content,
                                            trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
}
