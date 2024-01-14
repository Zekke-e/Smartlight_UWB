//
//  Mqtt.swift
//  Qorvo NI Background
//
//  Created by Wojciech Darul on 02/01/2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import CocoaMQTT

protocol didReceiveMessageDelegate {
    func setMessage(message: String)
}

class MQTT: CocoaMQTTDelegate {
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        print("test")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        print("test")

    }
    
    
    var delegate: didReceiveMessageDelegate?
    let mqttClient = CocoaMQTT(clientID: "test-mqttx_bb12c237", host: "broker.emqx.io", port: 1883)
    
    func connect() {
        mqttClient.delegate = self
        mqttClient.connect()
        print("Connecting...")
    }
    
    func disconnect() {
        mqttClient.disconnect()
        print("Disconnected")
    }
    
    func publish(topic: String, message: String) {
        mqttClient.publish(topic, withString: message)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print("Connected")
        mqttClient.subscribe("moj/top")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        let messageDecoded = String(bytes: message.payload, encoding: .utf8)
        print("Did receive a message: \(messageDecoded!)")
        delegate?.setMessage(message: "\(messageDecoded!) ºC")
        
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topic: String) {
        print("Did subscribe to \(topic)")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopic topic: String) {
        
    }
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {

    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        
    }
}
