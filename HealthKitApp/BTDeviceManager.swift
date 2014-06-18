//
//  BTDeviceManager.swift
//  HealthKitApp
//
//  Created by Ted Rogers on 6/10/14.
//  Copyright (c) 2014 Ted Rogers Consulting, LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BTDeviceManagerDelegate {
    func deviceConnected(deviceName: String)
    func deviceDisconnected()
    func newBluetoothState(blueToothOn: Bool, blueToothState: String)
    func newLocation(location: Int)
    func newBPM(bpm: UInt16)
}
    
class BTDeviceManager : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // track whether bluetooth is currenty on
    var blueToothOn : Bool = false
    // current BT state
    var blueToothState: String = "Unknown."
    // the central manager
    let _centralManager: CBCentralManager!
    // the queue for the central manager to operate on
    let _centralManagerQueue: dispatch_queue_t!
    // name of the central manager serial queue
    let _centralManagerQueueName: CString = "com.tedmrogers.centralmanagerqueue"
    // the heart rate monitor
    var _heartRateMonitor : CBPeripheral?
    // the callback delegate
    var delegate: BTDeviceManagerDelegate?
    
    // initializer
    init() {
        super.init()
        // create the serial queue for the central manager to use
        _centralManagerQueue = dispatch_queue_create(_centralManagerQueueName, DISPATCH_QUEUE_SERIAL)
        // create the central manager with us as the delegate
        _centralManager = CBCentralManager(delegate: self, queue: _centralManagerQueue)
    }
    
    // MARK: Implementation
    
    // start scanning for devices (peripherals)
    func startScan() {
        if (_centralManager.state == CBCentralManagerState.PoweredOn) {
            println("Scanning")
            let serviceUUID = CBUUID.UUIDWithString("180D")
            let serviceUUIDs = NSArray(object: serviceUUID)
            _centralManager.scanForPeripheralsWithServices(serviceUUIDs, options: nil)
           
        }
    }
    
    // start scanning for devices (peripherals)
    func findDevice() {
        if (_centralManager.state == CBCentralManagerState.PoweredOn) {
            println("Finding")
            let deviceUUIDString = NSUserDefaults.standardUserDefaults().stringForKey("MyDevice")
            if (deviceUUIDString) {
                let deviceUUID = CBUUID.UUIDWithString(deviceUUIDString)
                let devicdUUIDs = NSArray(object: deviceUUID)
                let knownPeripherals = _centralManager.retrievePeripheralsWithIdentifiers(devicdUUIDs)
                if (knownPeripherals?.count)
                {
                    let peripheral = knownPeripherals[0] as CBPeripheral
                    connectToPeripheral(peripheral)
                }
            }
        }
    }
    
    // set current Bluetooth state
    func setState(state: String) {
        blueToothState = state;
    }
    
    // connect to the found periperal
    func connectToPeripheral(peripheral: CBPeripheral) {
        _heartRateMonitor = peripheral;
        _centralManager.connectPeripheral(peripheral, options: nil)
    }
    
    // update the heart rate monitor value
    func updateWithHRMData(data: NSData) {
        let reportData: UnsafePointer<UInt8> = UnsafePointer<UInt8>(data.bytes);
        var bpm: UInt16 = 0;
        if ((reportData[0] & 0x01) == 0) {
            bpm = UInt16(reportData[1])
        } else {
           // bpm = CFSwapInt16LittleToHost
        }
        dispatch_async(dispatch_get_main_queue(), {
            println("bpm = \(bpm) length = \(data.length)")
            if let delegate = self.delegate {
                delegate.newBPM(bpm)
            }
        })
    }
    
    // update the sensor location
    func updateWithLocationData(location: UInt8) {
        dispatch_async(dispatch_get_main_queue(), {
            if let delegate = self.delegate {
                delegate.newLocation(Int(location))
            }
        })
    }
    
    // MARK: CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        blueToothOn = false;
        switch (central.state) {
        case CBCentralManagerState.Unsupported:
            setState("Not Supported.")
        case CBCentralManagerState.Unauthorized:
            setState("Not Authorized.")
        case CBCentralManagerState.PoweredOff:
            setState("Powered Off.")
        case CBCentralManagerState.PoweredOn:
            setState("Powered On.")
            blueToothOn = true;
        case CBCentralManagerState.Unknown:
            fallthrough
        default:
            setState("Unknown.")
        }
        dispatch_async(dispatch_get_main_queue(), {
            if let delegate = self.delegate {
                delegate.newBluetoothState(self.blueToothOn, blueToothState: self.blueToothState)
            }
        })
    }
    
    func centralManager(central: CBCentralManager!, willRestoreState dict: NSDictionary!) {
        
    }
    
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        println("\(__FUNCTION__)")
        dispatch_async(dispatch_get_main_queue(), {
            if let delegate = self.delegate {
                delegate.deviceConnected(peripheral.name)
            }
        })
        // get the id of this peripheral
        let deviceId = peripheral.identifier
        println("deviceId = \(deviceId)")
        // get the string for it for saving
        let deviceUUIDString = NSString(string: deviceId.UUIDString)
        println("deviceUUIDString = \(deviceUUIDString)")
        let userDefaults = NSUserDefaults.standardUserDefaults()
        println("userDefaults = \(userDefaults)")
        userDefaults.setObject(deviceUUIDString, forKey: "MyDevice")
        userDefaults.synchronize()
        peripheral.delegate = self;
        let serviceUUID = CBUUID.UUIDWithString("180D")
        let serviceUUIDs = NSArray(object: serviceUUID)
        peripheral.discoverServices(serviceUUIDs)
    }
    
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        if (error) {
            println("\(__FUNCTION__): error = \(error.description)")
            return
        }
        dispatch_async(dispatch_get_main_queue(), {
            if let delegate = self.delegate {
                delegate.deviceDisconnected()
            }
        })
    }
    
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: NSDictionary!, RSSI: NSNumber!) {
        println("\(__FUNCTION__) peripheral = \(peripheral)")
        let name = advertisementData.objectForKey("kCBAdvDataLocalName") as NSString
        _centralManager.stopScan()
        connectToPeripheral(peripheral)
    }
    
    func centralManager(central: CBCentralManager!, didFailToConnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        if (error) {
            println("\(__FUNCTION__): error = \(error.description)")
            return
        }
    }

    func centralManager(central: CBCentralManager!, didRetrieveConnectedPeripherals peripherals: AnyObject[]!) {
        for peripheral in peripherals as CBPeripheral[] {
            println("\(__FUNCTION__): peripheral = \(peripheral)")
        }
    }
    
    func centralManager(central: CBCentralManager!, didRetrievePeripherals peripherals: AnyObject[]!) {
        for peripheral in peripherals as CBPeripheral[] {
            println("\(__FUNCTION__): peripheral = \(peripheral)")
            if !_heartRateMonitor {
                connectToPeripheral(peripheral)
                break;
            }
        }
    }
    
    // MARK: CBPeripheralDelegate
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        if (error) {
            println("\(__FUNCTION__): error = \(error.description)")
            return
        }
        let services = peripheral.services as CBService[]
        for service in services {
            println("\(__FUNCTION__): service = \(services)")
            peripheral.discoverCharacteristics(nil, forService: service)
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        if (error) {
            println("\(__FUNCTION__): error = \(error.description)")
            return
        }
        let charcteristics = service.characteristics as CBCharacteristic[]
        for characteristic in charcteristics {
//            println("characteristic = \(characteristic) value = \(characteristic.value) UUID = \(characteristic.UUID) isNotifying = \(characteristic.isNotifying) isBroadcasted = \(characteristic.isBroadcasted)")
            // set notification for heart rate measurement
            if characteristic.UUID.isEqual(CBUUID.UUIDWithString("2A37")) {
                println("\(__FUNCTION__): Found a heart rate measurement characteristic")
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
            }
            // read the body sensor location
            if (characteristic.UUID.isEqual(CBUUID.UUIDWithString("2A38"))) {
                println("\(__FUNCTION__): Found a body sensor location characterstic")
                peripheral.readValueForCharacteristic(characteristic)
            }
            // write heart rate control point
            if (characteristic.UUID.isEqual(CBUUID.UUIDWithString("2A39"))) {
                let valArray :UInt8[] = [1]
                let valData = NSData(bytes: valArray, length: valArray.count)
                peripheral.writeValue(valData, forCharacteristic: characteristic, type: CBCharacteristicWriteType.WithResponse)
            }
            // get descriptors for this characteristic
            peripheral.discoverDescriptorsForCharacteristic(characteristic)
        }
    }

    func peripheral(peripheral: CBPeripheral!, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        if (error) {
            println("\(__FUNCTION__): error = \(error.description)")
            return
        }
        let descriptors = characteristic.descriptors as CBDescriptor[]
        for descriptor in descriptors {
            println("\(__FUNCTION__): descriptor = \(descriptor) UUID = \(descriptor.UUID) value = \(descriptor.value)")
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error : NSError!) {
        if (error) {
            println("\(__FUNCTION__): error = \(error.description)")
            return
        }
        println("thread = \(NSThread.currentThread()) queue = \(dispatch_get_current_queue())")
//        println("characteristic = \(characteristic) value = \(characteristic.value) UUID = \(characteristic.UUID) isNotifying = \(characteristic.isNotifying) isBroadcasted = \(characteristic.isBroadcasted)")
        // Updated heart rate measurment
        if characteristic.UUID.isEqual(CBUUID.UUIDWithString("2A37")) {
            println("Updated heart rate measurement characteristic")
            if characteristic.value {
                let data = characteristic.value
                updateWithHRMData(data)
            }
        } else
        // read the body sensor location
        if (characteristic.UUID.isEqual(CBUUID.UUIDWithString("2A38"))) {
            println("Updated body sensor location characterstic")
            let data = characteristic.value
            let reportData: UnsafePointer<UInt8> = UnsafePointer<UInt8>(data.bytes);
            let location = reportData[0]
            updateWithLocationData(location)
            println("location = \(location)")
        }
     }
    
    func peripheral(peripheral: CBPeripheral!, didWriteValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        println("\(__FUNCTION__)")
        if (error) {
            println("\(__FUNCTION__): error = \(error.description)")
            return
        }
    }
}
