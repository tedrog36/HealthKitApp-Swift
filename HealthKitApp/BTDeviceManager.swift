//
//  BTDeviceManager.swift
//  HealthKitApp
//
//  Created by Ted Rogers on 6/10/14.
//  Copyright (c) 2014 Ted Rogers Consulting, LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BTDeviceManagerDelegate: class {
    func deviceConnected(_ deviceName: String)
    func deviceDisconnected()
    func newBluetoothState(_ blueToothOn: Bool, blueToothState: String)
    func newLocation(_ location: Int)
    func newBPM(_ bpm: UInt16)
}

extension CBCentralManager {
    internal var centralManagerState: CBCentralManagerState  {
        get {
            return CBCentralManagerState(rawValue: state.rawValue) ?? .unknown
        }
    }
}

class BTDeviceManager : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    // heart rate monitor service uuid
    let heartRateServiceUUID = CBUUID(string: "180D")
    // heart rate measurement characteristic
    let heartRateMeasurementCharacteristic = CBUUID(string: "2A37")
    // sensor location characteristic
    let sensorLocationCharacteristic = CBUUID(string: "2A38")
    // heart rate control point characteristic
    let heartRateControlPointCharacteristic = CBUUID(string: "2A39")
    // device id key
    let deviceIdKey = "MyDevice"
    // track whether bluetooth is currenty on
    var blueToothOn : Bool = false
    // current BT state
    var blueToothState = "Unknown."
    // the central manager
    var centralManager: CBCentralManager! // implicitly unwrapped optional because its init needs self
    // the queue for the central manager to operate on
    let centralManagerQueue: DispatchQueue
    // name of the central manager serial queue
    let centralManagerQueueName = "com.tedmrogers.centralmanagerqueue"
    // the heart rate monitor
    var heartRateMonitor : CBPeripheral?
    // the callback delegate
    weak var delegate: BTDeviceManagerDelegate?
    
    // initializer
    override init() {
        // create the serial queue for the central manager to use
        centralManagerQueue = DispatchQueue(label: centralManagerQueueName, attributes: [])
        super.init()
        // create the central manager with us as the delegate
        // this is an example of a case where you would used an implicitly unwrapped optional
        // because you cannot create the object without self and you cannot create self if you
        // haven't defined all non-optionals
        centralManager = CBCentralManager(delegate: self, queue: centralManagerQueue)
    }
    
    // MARK: Implementation
    
    // start scanning for devices (peripherals)
    func startScan() {
        if centralManager.centralManagerState == CBCentralManagerState.poweredOn {
            print("Scanning")
            let serviceUUIDs = [heartRateServiceUUID];
            centralManager.scanForPeripherals(withServices: serviceUUIDs, options: nil)
        }
    }
    
    // start scanning for devices (peripherals)
    func findDevice() {
        if centralManager.centralManagerState == CBCentralManagerState.poweredOn {
            print("Finding")
            if let deviceUUIDString = UserDefaults.standard.string(forKey: deviceIdKey) {
                let deviceUUID = UUID(uuidString: deviceUUIDString)!
                let deviceUUIDs = [deviceUUID];
                let knownPeripherals = centralManager.retrievePeripherals(withIdentifiers: deviceUUIDs)
                if knownPeripherals.count > 0 {
                    let peripheral = knownPeripherals[0] as CBPeripheral
                    connectToPeripheral(peripheral)
                }
            }
        }
    }
    
    // set current Bluetooth state
    func setState(_ state: String) {
        blueToothState = state;
    }
    
    // connect to the found periperal
    func connectToPeripheral(_ peripheral: CBPeripheral) {
        heartRateMonitor = peripheral;
        centralManager.connect(peripheral, options: nil)
    }
    
    // update the heart rate monitor value
    func updateWithHRMData(_ data: Data) {
        let reportData: UnsafePointer<UInt8> = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count);
        var bpm: UInt16 = 0;
        if ((reportData[0] & 0x01) == 0) {
            bpm = UInt16(reportData[1])
        } else {
           // bpm = CFSwapInt16LittleToHost
        }
        DispatchQueue.main.async() {
            print("bpm = \(bpm) length = \(data.count)")
            if let delegate = self.delegate {
                delegate.newBPM(bpm)
            }
        }
    }
    
    // update the sensor location
    func updateWithLocationData(_ location: UInt8) {
        DispatchQueue.main.async() {
            if let delegate = self.delegate {
                delegate.newLocation(Int(location))
            }
        }
    }
    
    // MARK: CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        blueToothOn = false;
        switch (central.centralManagerState) {
        case CBCentralManagerState.unsupported:
            setState("Not Supported.")
        case CBCentralManagerState.unauthorized:
            setState("Not Authorized.")
        case CBCentralManagerState.poweredOff:
            setState("Powered Off.")
        case CBCentralManagerState.poweredOn:
            setState("Powered On.")
            blueToothOn = true;
        case CBCentralManagerState.unknown:
            fallthrough
        default:
            setState("Unknown.")
        }
        DispatchQueue.main.async() {
            if let delegate = self.delegate {
                delegate.newBluetoothState(self.blueToothOn, blueToothState: self.blueToothState)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("\(#function)")
        DispatchQueue.main.async() {
            if let delegate = self.delegate {
                delegate.deviceConnected(peripheral.name!)
            }
        }
        // get the id of this peripheral
        let deviceId = peripheral.identifier
        print("deviceId = \(deviceId)")
        // get the string for it for saving
        let deviceUUIDString = NSString(string: deviceId.uuidString)
        print("deviceUUIDString = \(deviceUUIDString)")
        let userDefaults = UserDefaults.standard
        userDefaults.set(deviceUUIDString, forKey: "MyDevice")
        userDefaults.synchronize()
        peripheral.delegate = self;
        let serviceUUIDs = [heartRateServiceUUID]
        peripheral.discoverServices(serviceUUIDs)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let theError = error {
            print("\(#function): error = \(theError.localizedDescription)")
            return
        }
        DispatchQueue.main.async() {
            if let delegate = self.delegate {
                delegate.deviceDisconnected()
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = advertisementData["kCBAdvDataLocalName"];
        print("\(#function) peripheral = \(peripheral) name = \(name)")
        centralManager.stopScan()
        connectToPeripheral(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let theError = error {
            print("\(#function): error = \(theError.localizedDescription)")
            return
        }
    }

    func centralManager(_ central: CBCentralManager!, didRetrieveConnectedPeripherals peripherals: [AnyObject]!) {
        for peripheral in peripherals as! [CBPeripheral] {
            print("\(#function): peripheral = \(peripheral)")
        }
    }
    
    func centralManager(_ central: CBCentralManager!, didRetrievePeripherals peripherals: [AnyObject]!) {
        for peripheral in peripherals as! [CBPeripheral] {
            print("\(#function): peripheral = \(peripheral)")
            if !(heartRateMonitor != nil) {
                connectToPeripheral(peripheral)
                break;
            }
        }
    }
    
    // MARK: CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let theError = error {
            print("\(#function): error = \(theError.localizedDescription)")
            return
        }
        let services = peripheral.services! as [CBService]
        for service in services {
            print("\(#function): service = \(services)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let theError = error {
            print("\(#function): error = \(theError.localizedDescription)")
            return
        }
        let charcteristics = service.characteristics! as [CBCharacteristic]
        for characteristic in charcteristics {
//            print("characteristic = \(characteristic) value = \(characteristic.value) UUID = \(characteristic.UUID) isNotifying = \(characteristic.isNotifying) isBroadcasted = \(characteristic.isBroadcasted)")
            // set notification for heart rate measurement
            if characteristic.uuid.isEqual(heartRateMeasurementCharacteristic) {
                print("\(#function): Found a heart rate measurement characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
            }
            // read the body sensor location
            if characteristic.uuid.isEqual(sensorLocationCharacteristic) {
                print("\(#function): Found a body sensor location characterstic")
                peripheral.readValue(for: characteristic)
            }
            // write heart rate control point
            if characteristic.uuid.isEqual(heartRateControlPointCharacteristic) {
                let valArray :[UInt8] = [1]
                let valData = NSData(bytes: valArray, length: valArray.count)
                peripheral.writeValue(valData as Data, for: characteristic, type: CBCharacteristicWriteType.withResponse)
            }
            // get descriptors for this characteristic
            peripheral.discoverDescriptors(for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if let theError = error {
            print("\(#function): error = \(theError.localizedDescription)")
            return
        }
        let descriptors = characteristic.descriptors! as [CBDescriptor]
        for descriptor in descriptors {
            print("\(#function): descriptor = \(descriptor) UUID = \(descriptor.uuid) value = \(descriptor.value)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error : Error?) {
        if let theError = error {
            print("\(#function): error = \(theError.localizedDescription)")
            return
        }
        print("thread = \(Thread.current)")
//        print("characteristic = \(characteristic) value = \(characteristic.value) UUID = \(characteristic.UUID) isNotifying = \(characteristic.isNotifying) isBroadcasted = \(characteristic.isBroadcasted)")
        // Updated heart rate measurment
        if characteristic.uuid.isEqual(heartRateMeasurementCharacteristic) {
            print("Updated heart rate measurement characteristic")
            if let data = characteristic.value {
                updateWithHRMData(data)
            }
        } else
        // read the body sensor location
        if characteristic.uuid.isEqual(sensorLocationCharacteristic) {
            print("Updated body sensor location characterstic")
            if let data = characteristic.value {
                if let location = data.first {
                    updateWithLocationData(location)
                    print("location = \(location)")
                }
            }
        }
     }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("\(#function)")
        if let theError = error {
            print("\(#function): error = \(theError.localizedDescription)")
            return
        }
    }
}
