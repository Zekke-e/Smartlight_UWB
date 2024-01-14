/*
 * @file      QorvoDemoViewController.swift
 *
 * @brief     Main Application View Controller.
 *
 * @author    Decawave Applications
 *
 * @attention Copyright (c) 2021 - 2022, Qorvo US, Inc.
 * All rights reserved
 * Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright notice, this
 *  list of conditions, and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *  this list of conditions and the following disclaimer in the documentation
 *  and/or other materials provided with the distribution.
 * 3. You may only use this software, with or without any modification, with an
 *  integrated circuit developed by Qorvo US, Inc. or any of its affiliates
 *  (collectively, "Qorvo"), or any module that contains such integrated circuit.
 * 4. You may not reverse engineer, disassemble, decompile, decode, adapt, or
 *  otherwise attempt to derive or gain access to the source code to any software
 *  distributed under this license in binary or object code form, in whole or in
 *  part.
 * 5. You may not use any Qorvo name, trademarks, service marks, trade dress,
 *  logos, trade names, or other symbols or insignia identifying the source of
 *  Qorvo's products or services, or the names of any of Qorvo's developers to
 *  endorse or promote products derived from this software without specific prior
 *  written permission from Qorvo US, Inc. You must not call products derived from
 *  this software "Qorvo", you must not have "Qorvo" appear in their name, without
 *  the prior permission from Qorvo US, Inc.
 * 6. Qorvo may publish revised or new version of this license from time to time.
 *  No one other than Qorvo US, Inc. has the right to modify the terms applicable
 *  to the software provided under this license.
 * THIS SOFTWARE IS PROVIDED BY QORVO US, INC. "AS IS" AND ANY EXPRESS OR IMPLIED
 *  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. NEITHER
 *  QORVO, NOR ANY PERSON ASSOCIATED WITH QORVO MAKES ANY WARRANTY OR
 *  REPRESENTATION WITH RESPECT TO THE COMPLETENESS, SECURITY, RELIABILITY, OR
 *  ACCURACY OF THE SOFTWARE, THAT IT IS ERROR FREE OR THAT ANY DEFECTS WILL BE
 *  CORRECTED, OR THAT THE SOFTWARE WILL OTHERWISE MEET YOUR NEEDS OR EXPECTATIONS.
 * IN NO EVENT SHALL QORVO OR ANYBODY ASSOCIATED WITH QORVO BE LIABLE FOR ANY
 *  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 *  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 *  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 *
 */
import UIKit
import NearbyInteraction
import SceneKit
import CoreHaptics
import AVFoundation
import os.log

// An example messaging protocol for communications between the app and the
// accessory. In your app, modify or extend this enumeration to your app's
// user experience and conform the accessory accordingly.
enum MessageId: UInt8 {
    // Messages from the accessory.
    case accessoryConfigurationData = 0x1
    case accessoryUwbDidStart = 0x2
    case accessoryUwbDidStop = 0x3
    case accessoryPaired = 0x4
    
    // Messages to the accessory.
    case initialize = 0xA
    case configureAndStart = 0xB
    case stop = 0xC
    
    // User defined Message IDs
    case getDeviceStruct = 0x20
    case setDeviceStruct = 0x21

    case iOSNotify = 0x2F
}

// Base struct for the feedback array implementing three different feedback levels
struct FeedbackLvl {
    var hummDuration: TimeInterval
    var timerIndexRef: Int
}

class AccessoryDemoViewController: UIViewController,
                                   UITableViewDelegate,
                                   UITableViewDataSource,
                                   didReceiveMessageDelegate{
    
    static let mqtt = MQTT()
    func setMessage(message: String) {
        print("TEST")
    }
    
    @IBOutlet weak var accessoriesTable: UITableView!
    
    let qorvoGray = UIColor(red: 249/255, green: 249/255, blue: 249/255, alpha: 1.00)
    let qorvoBlue = UIColor(red: 0.00,    green: 159/255, blue: 1.00,    alpha: 1.00)
    let qorvoRed  = UIColor(red: 1.00,    green: 123/255, blue: 123/255, alpha: 1.00)
    
    var dataChannel = DataCommunicationChannel()
    var notifier = NotificationManager.instance
    
    var configuration: NINearbyAccessoryConfiguration?
    var selectExpand = true

    // Used to animate scanning images
    var imageScanningSmall = [UIImage]()
    
    // Dictionary to associate each NI Session to the qorvoDevice using the uniqueID
    var referenceDict = [Int:NISession]()
    // A mapping from a discovery token to a name.
    var accessoryMap = [NIDiscoveryToken: String]()
    
    // Settings from View are initialised by the main controller, wich use these settings
    let savedSettings = UserDefaults.standard
    
    // Auxiliary variables for feedback
    var engine: CHHapticEngine?
    var feedbackDisabled: Bool = true
    var feedbackLevel: Int = 0
    var feedbackLevelOld: Int = 0
    var feedbackPar: [FeedbackLvl] = [FeedbackLvl(hummDuration: 1.0, timerIndexRef: 8),
                                      FeedbackLvl(hummDuration: 0.5, timerIndexRef: 4),
                                      FeedbackLvl(hummDuration: 0.1, timerIndexRef: 1)]
    // Auxiliary variables to handle the feedback Timer
    var timerIndex: Int = 0

    let logger = os.Logger(subsystem: "com.example.apple-samplecode.NINearbyAccessorySample",
                           category: "AccessoryDemoViewController")
    
    let btnDisabled = "Disabled"
    let btnConnect = "Connect"
    let btnDisconnect = "Disconnect"
    let devNotConnected = "NO ACCESSORY CONNECTED"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AccessoryDemoViewController.mqtt.delegate = self
        AccessoryDemoViewController.mqtt.connect()
        
        // Notification from Settings View Controller
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(clearKnownDevices),
                                               name: Notification.Name("clearKnownDevices"),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(settingsNotification),
                                               name: Notification.Name("settingsNotification"),
                                               object: nil)
        
        notifier.requestAuthorization()
        
        // Initialise Settings
        if let state = savedSettings.object(forKey: "settingsNotification") as? Bool {
            appSettings.pushNotificationEnabled = state
        }
        
        // Prepare the data communication channel.
        dataChannel.accessoryDiscoveryHandler = accessoryInclude
        dataChannel.accessoryTimeoutHandler = accessoryRemove
        dataChannel.accessoryPairHandler = accessoryPaired
        dataChannel.accessoryConnectedHandler = accessoryConnected
        dataChannel.accessoryDisconnectedHandler = accessoryDisconnected
        dataChannel.accessoryDataHandler = accessorySharedData
        dataChannel.start()
        
        // Get NISession Device Capabilities
        let capabilities = NISession.deviceCapabilities
        
        appSettings.supportsPreciseDistanceMeasurement = capabilities.supportsPreciseDistanceMeasurement
        appSettings.supportsCameraAssistance = capabilities.supportsCameraAssistance
        appSettings.supportsDirectionMeasurement = capabilities.supportsDirectionMeasurement
        
        // Creates the scanning animation from a static image
        let imageSmall = UIImage(named: "spinner_small.svg")!
        for i in 0...24 {
            imageScanningSmall.append(imageSmall.rotate(radians: Float(i) * .pi / 12)!)
        }
        
        // Initialises table to stack devices from qorvoDevices
        accessoriesTable.delegate   = self
        accessoriesTable.dataSource = self
        
        logger.info("Scanning for accessories")
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    @objc func clearKnownDevices(notification: NSNotification) {
        dataChannel.clearKnownDevices()
    }
    
    @objc func settingsNotification(notification: NSNotification) {
        savedSettings.set(appSettings.pushNotificationEnabled, forKey: "settingsNotification")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return qorvoDevices.count
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let disconnect = UIContextualAction(style: .normal, title: "") { [self] (action, view, completion) in
            // Send the disconnection message to the device
            let cell = accessoriesTable.cellForRow(at: indexPath) as! DeviceTableViewCell
            let deviceID = cell.uniqueID
            let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID)
            
            if qorvoDevice?.blePeripheralStatus != statusDiscovered {
                sendDataToAccessory(Data([MessageId.stop.rawValue]), deviceID)
            }
            completion(true)
        }
        // Set the Contextual action parameters
        disconnect.image = UIImage(named: "trash_bin")
        disconnect.backgroundColor = qorvoRed
        
        let swipeActions = UISwipeActionsConfiguration(actions: [disconnect])
        swipeActions.performsFirstActionWithFullSwipe = false
        
        return swipeActions
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = accessoriesTable.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! DeviceTableViewCell
        
        let qorvoDevice = qorvoDevices[indexPath.row]
        
        cell.uniqueID = (qorvoDevice?.bleUniqueID)!
        
        // Initialize the new cell assets
        cell.tag = indexPath.row
        cell.accessoryButton.tag = indexPath.row
        cell.accessoryButton.setTitle(qorvoDevice?.blePeripheralName, for: .normal)

        cell.actionButton.tag = indexPath.row
        cell.actionButton.addTarget(self,
                                    action: #selector(buttonAction),
                                    for: .touchUpInside)
        cell.scanning.animationImages = imageScanningSmall
        cell.scanning.animationDuration = 1

        logger.info("New device included at row \(indexPath.row)")
        
        return cell
    }
    
    @IBAction func buttonAction(_ sender: UIButton) {
        reqConnectionByIndex(sender.tag)
    }
    
    func reqConnectionByIndex(_ index: NSInteger) {
        // Get qorvo device that's match with sender's tag
        if let qorvoDevice = qorvoDevices[index] {
            let deviceID = qorvoDevice.bleUniqueID

            // Connect to the accessory
            if qorvoDevice.blePeripheralStatus == statusDiscovered {
                logger.info("Connecting to Accessory")
                AccessoryDemoViewController.mqtt.connect()
                connectToAccessory(deviceID)
            }
            else {
                return
            }
            
            // Edit cell for this sender
            for case let cell as DeviceTableViewCell in accessoriesTable.visibleCells {
                if cell.tag == index {
                    cell.selectAsset(.scanning)
                }
            }
            
            logger.info("Action requested for device \(deviceID)")
        }
    }
    
    func reqConnectionByID(_ deviceID: Int) {
        // Get qorvo device that's match with sender's tag
        if let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID) {

            // Connect to the accessory
            if qorvoDevice.blePeripheralStatus == statusDiscovered {
                logger.info("Connecting to Accessory")
                connectToAccessory(deviceID)
            }
            else {
                return
            }

            if let index = qorvoDevices.firstIndex(where: {$0?.bleUniqueID == deviceID}) {
                // Edit cell for this sender
                for case let cell as DeviceTableViewCell in accessoriesTable.visibleCells {
                    if cell.tag == index {
                        cell.selectAsset(.scanning)
                    }
                }
            }

            logger.info("Action requested for device \(deviceID)")
        }
    }
    
    func setFeedbackLvl(distance: Float) {
        // Select feedback Level according to the distance
        if distance > 4.0 {
            feedbackLevel = 0
        }
        else if distance > 2.0{
            feedbackLevel = 1
        }
        else {
            feedbackLevel = 2
        }
        
        // If level changes, apply immediately
        if feedbackLevel != feedbackLevelOld {
            timerIndex = 0
            feedbackLevelOld = feedbackLevel
        }
    }
        
    func updateDeviceList()-> Int {
        var index = 0
        
        // Add new devices, if any
        qorvoDevices.forEach { (qorvoDevice) in
            // Flag to check if the device is already included
            var includeToTable = true
            
            for case let cell as DeviceTableViewCell in accessoriesTable.visibleCells {
                if cell.uniqueID == qorvoDevice?.bleUniqueID {
                    // Device doesn't need to be included
                    includeToTable = false
                    // Update indexes tags
                    cell.tag                 = index
                    cell.actionButton.tag    = index
                    cell.accessoryButton.tag = index
                    
                    // Update cell based on status
                    if qorvoDevice?.blePeripheralStatus == statusDiscovered {
                        cell.selectAsset(.actionButton)
                    }
                }
            }
            
            // If not, include a new row
            if includeToTable {
                accessoriesTable.performBatchUpdates({
                    accessoriesTable.insertRows(at: [IndexPath(row: index, section: 0)],
                                                with: .automatic) }, completion: nil)
            }
            
            index = index + 1
        }
        
        // Remove devices, if they are no longer included
        for case let cell as DeviceTableViewCell in accessoriesTable.visibleCells {
            // Check if the cell reference is in qorvoDevices
            var removeFromTable = true
            
            qorvoDevices.forEach { (qorvoDevice) in
                if cell.uniqueID == qorvoDevice?.bleUniqueID {
                    removeFromTable = false
                }
            }
            
            // If not, remove the cell
            if removeFromTable {
                if let indexPath = accessoriesTable.indexPath(for: cell) {
                    accessoriesTable.deleteRows(at: [indexPath], with: .fade)
                }
            }
        }
        
        return index
    }

    // MARK: - Data channel methods
    func accessorySharedData(data: Data, accessoryName: String, deviceID: Int) {
        // The accessory begins each message with an identifier byte.
        // Ensure the message length is within a valid range.
        if data.count < 1 {
            logger.info("Accessory shared data length was less than 1.")
            return
        }
        
        // Assign the first byte which is the message identifier.
        guard let messageId = MessageId(rawValue: data.first!) else {
            fatalError("\(data.first!) is not a valid MessageId.")
        }
        
        // Handle the data portion of the message based on the message identifier.
        switch messageId {
        case .accessoryConfigurationData:
            // Access the message data by skipping the message identifier.
            assert(data.count > 1)
            let message = data.advanced(by: 1)
            runBackgroundNISession(message, name: accessoryName, deviceID: deviceID)
        case .accessoryUwbDidStart:
            handleAccessoryUwbDidStart(deviceID)
        case .accessoryUwbDidStop:
            handleAccessoryUwbDidStop(deviceID)
        case .accessoryPaired:
            accessoryPaired(data: data, deviceID: deviceID)
        case .configureAndStart:
            fatalError("Accessory should not send 'configureAndStart'.")
        case .initialize:
            fatalError("Accessory should not send 'initialize'.")
        case .stop:
            fatalError("Accessory should not send 'stop'.")
        // User defined messages
        case .getDeviceStruct:
            print("Action Reserved.")
        case .setDeviceStruct:
            print("Action Reserved.")
        case .iOSNotify:
            if appSettings.pushNotificationEnabled! {
                let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID)
                
                if let message = String(bytes: data.advanced(by: 3), encoding: .utf8) {
                    notifier.setNotification(deviceName: qorvoDevice!.blePeripheralName,
                                             deviceMessage: message)
                }
            }
        }
    }
    
    func accessoryInclude(deviceID: Int, newDevice: Bool) {
        var index = 0
        
        for case let cell as DeviceTableViewCell in accessoriesTable.visibleCells {
            if cell.uniqueID == deviceID {
                break
            }
            index += 1
        }

        accessoriesTable.beginUpdates()
        accessoriesTable.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        accessoriesTable.endUpdates()
        
        if newDevice, dataChannel.checkPairedDevice(deviceID) {
            reqConnectionByID(deviceID)
        }
    }
    
    func accessoryRemove(deviceID: Int) {
        var index = 0
        
        for case let cell as DeviceTableViewCell in accessoriesTable.visibleCells {
            if cell.uniqueID == deviceID {
                break
            }
            index += 1
        }
        
        accessoriesTable.beginUpdates()
        accessoriesTable.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        accessoriesTable.endUpdates()
    }

    
    func accessoryConnected(deviceID: Int) {
        pairToAccessory(deviceID)
    }
    
    func accessoryPaired(data: Data, deviceID: Int) {
        // Add device if not added yet
        if !(dataChannel.checkPairedDevice(deviceID)) {
            dataChannel.includePairedDevice(deviceID, "test")
        }
        
        // Create a NISession for the new device
        referenceDict[deviceID] = NISession()
        referenceDict[deviceID]?.delegate = self
        
        logger.info("Requesting configuration data from accessory")
        let msg = Data([MessageId.initialize.rawValue])
        
        sendDataToAccessory(msg, deviceID)
    }
    
    func accessoryDisconnected(deviceID: Int) {
        // Invalidate NI Session before remove it
        referenceDict[deviceID]?.invalidate()
        
        // Remove the NI Session and Location values related to the device ID
        referenceDict.removeValue(forKey: deviceID)
        
        // Update device list and take other actions depending on the amount of devices
        let _ = updateDeviceList()
        
        logger.info("Accessory \(deviceID) disconnected")
    }
    
    // MARK: - Accessory messages handling
    func runBackgroundNISession(_ configData: Data, name: String, deviceID: Int) {
        logger.info("Received configuration data from '\(name)'. Running session.")
        
        // Get peerIdentifier from the connacted device
        let peerDevice = dataChannel.getDeviceFromUniqueID(deviceID)
        let peerIdentifier = peerDevice!.blePeripheral.identifier
        
        do {
            configuration = try NINearbyAccessoryConfiguration(accessoryData: configData,                                                                                bluetoothPeerIdentifier: peerIdentifier)
        } catch {
            // Stop and display the issue because the incoming data is invalid.
            // In your app, debug the accessory data to ensure an expected
            // format.
            logger.info("Failed to create NINearbyAccessoryConfiguration for '\(name)'. Error: \(error)")
            return
        }
        
        // Cache the token to correlate updates with this accessory.
        cacheToken(configuration!.accessoryDiscoveryToken, accessoryName: name)
        
        referenceDict[deviceID]?.run(configuration!)
        logger.info("Accessory Background Session configured.")
    }
    
    func handleAccessoryUwbDidStart(_ deviceID: Int) {
        logger.info("Accessory Session started.")
        
        // Update the device Status
        if let startedDevice = dataChannel.getDeviceFromUniqueID(deviceID) {
            startedDevice.blePeripheralStatus = statusRanging
        }
        
        for case let cell as DeviceTableViewCell in accessoriesTable.visibleCells {
            if cell.uniqueID == deviceID {
                cell.selectAsset(.miniLocation)
            }
        }
    }
    
    func handleAccessoryUwbDidStop(_ deviceID: Int) {
        logger.info("Accessory Session stopped.")
        
        // Disconnect from device
        disconnectFromAccessory(deviceID)
    }
    
    func updateMiniFields(_ deviceID: Int) {
        
        if let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID) {
            // Get updated location values
            let distance  = qorvoDevice.uwbDistance
            
            AccessoryDemoViewController.mqtt.publish(topic: "moj/top", message: String(distance))
            
            for case let cell as DeviceTableViewCell in accessoriesTable.visibleCells {
                if cell.uniqueID == deviceID {
                    cell.distanceLabel.text = String(format: "%0.1f m", distance)
                }
            }
        }
    }
}

// MARK: - `NISessionDelegate`.
extension AccessoryDemoViewController: NISessionDelegate {

    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {
        guard object.discoveryToken == configuration?.accessoryDiscoveryToken else { return }
        
        // Prepare to send a message to the accessory.
        var msg = Data([MessageId.configureAndStart.rawValue])
        msg.append(shareableConfigurationData)
        
        let str = msg.map { String(format: "0x%02x, ", $0) }.joined()
        logger.info("Sending shareable configuration bytes: \(str)")
        
        // Send the message to the correspondent accessory.
        sendDataToAccessory(msg, deviceIDFromSession(session))
        logger.info("Sent shareable configuration data.")
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let accessory = nearbyObjects.first else { return }
        guard let distance  = accessory.distance else { return }
        
        let deviceID = deviceIDFromSession(session)
        
        if let updatedDevice = dataChannel.getDeviceFromUniqueID(deviceID) {
            // set updated values
            updatedDevice.uwbDistance = distance
            updatedDevice.blePeripheralStatus = statusRanging
        }
        
        updateMiniFields(deviceID)
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        
        // Retry the session only if the peer timed out.
        guard reason == .timeout else { return }
        logger.info("Session timed out.")
        
        // The session runs with one accessory.
        guard let accessory = nearbyObjects.first else { return }
        
        // Clear the app's accessory state.
        accessoryMap.removeValue(forKey: accessory.discoveryToken)
        
        // Get the deviceID associated to the NISession
        let deviceID = deviceIDFromSession(session)
        
        // Consult helper function to decide whether or not to retry.
        if shouldRetry(deviceID) {
            sendDataToAccessory(Data([MessageId.stop.rawValue]), deviceID)
            sendDataToAccessory(Data([MessageId.initialize.rawValue]), deviceID)
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        logger.info("Session was suspended.")
        let msg = Data([MessageId.stop.rawValue])
        
        sendDataToAccessory(msg, deviceIDFromSession(session))
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        logger.info("Session suspension ended.")
        // When suspension ends, restart the configuration procedure with the accessory.
        let msg = Data([MessageId.initialize.rawValue])
        
        sendDataToAccessory(msg, deviceIDFromSession(session))
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        let deviceID = deviceIDFromSession(session)
        
        switch error {
        case NIError.invalidConfiguration:
            // Debug the accessory data to ensure an expected format.
            logger.info("The accessory configuration data is invalid. Please debug it and try again.")
        case NIError.userDidNotAllow:
            handleUserDidNotAllow()
        default:
            handleSessionInvalidation(deviceID)
        }
    }
}

// MARK: - Helpers.
extension AccessoryDemoViewController {
    
    func pairToAccessory(_ deviceID: Int) {
         do {
             try dataChannel.pairPeripheral(deviceID)
         } catch {
             logger.info("Failed to pair to accessory: \(error)")
         }
    }
    
    func connectToAccessory(_ deviceID: Int) {
         do {
             try dataChannel.connectPeripheral(deviceID)
         } catch {
             logger.info("Failed to connect to accessory: \(error)")
         }
    }
    
    func disconnectFromAccessory(_ deviceID: Int) {
         do {
             try dataChannel.disconnectPeripheral(deviceID)
         } catch {
             logger.info("Failed to disconnect from accessory: \(error)")
         }
    }
    
    func sendDataToAccessory(_ data: Data,_ deviceID: Int) {
         do {
             try dataChannel.sendData(data, deviceID)
         } catch {
             logger.info("Failed to send data to accessory: \(error)")
         }
    }
    
    func handleSessionInvalidation(_ deviceID: Int) {
        logger.info("Session invalidated. Restarting.")
        // Ask the accessory to stop.
        sendDataToAccessory(Data([MessageId.stop.rawValue]), deviceID)

        // Replace the invalidated session with a new one.
        referenceDict[deviceID] = NISession()
        referenceDict[deviceID]?.delegate = self

        // Ask the accessory to stop.
        sendDataToAccessory(Data([MessageId.initialize.rawValue]), deviceID)
    }
    
    func shouldRetry(_ deviceID: Int) -> Bool {
        // Need to use the dictionary here, to know which device failed and check its connection state
        let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID)
        
        if qorvoDevice?.blePeripheralStatus != statusDiscovered {
            return true
        }
        
        return false
    }
    
    func deviceIDFromSession(_ session: NISession)-> Int {
        var deviceID = -1
        
        for (key, value) in referenceDict {
            if value == session {
                deviceID = key
            }
        }
        
        return deviceID
    }
    
    func cacheToken(_ token: NIDiscoveryToken, accessoryName: String) {
        accessoryMap[token] = accessoryName
    }
    
    func handleUserDidNotAllow() {
        // Beginning in iOS 15, persistent access state in Settings.
        logger.info("Nearby Interactions access required. You can change access for NIAccessory in Settings.")
        
        // Create an alert to request the user go to Settings.
        let accessAlert = UIAlertController(title: "Access Required",
                                            message: """
                                            NIAccessory requires access to Nearby Interactions for this sample app.
                                            Use this string to explain to users which functionality will be enabled if they change
                                            Nearby Interactions access in Settings.
                                            """,
                                            preferredStyle: .alert)
        accessAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        accessAlert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: {_ in
            // Navigate the user to the app's settings.
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }))

        // Preset the access alert.
        present(accessAlert, animated: true, completion: nil)
    }
}
