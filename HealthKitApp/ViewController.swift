//
//  ViewController.swift
//  HealthKitApp
//
//  Created by Ted Rogers on 6/10/14.
//  Copyright (c) 2014 Ted Rogers Consulting, LLC. All rights reserved.
//

import UIKit
import HealthKit

class ViewController: UIViewController, BTDeviceManagerDelegate {
    // MARK: Contants
    let minTimeBetweenReadings: NSTimeInterval = 0.200  // value to debounce repeated readings from BT device
    let oldReadingTime: NSTimeInterval = 30             // readings older than this are discarded
    let heartRateUnit = HKUnit(fromString: "count/min") // or HKUnit.countUnit().unitDividedByUnit(HKUnit.minuteUnit())
    
    // MARK: properties
    // the bluetooth device manager object
    var _deviceManager: BTDeviceManager!    // implicitly unwrapped optional
    // the health store - can be null if we don't get permission
    var healthStore: HKHealthStore?         // optional
    // track time of last reading.  My heart rate monitor is providing two readings back to back
    // so this is the drop one on the floor
    var lastReadingTime: NSDate = NSDate.distantPast() as NSDate
    // the device sensor location from the devcie mananger
    var deviceSensorLocation = HKHeartRateSensorLocation.Other
    // the device sensor location returned from HealthKit
    var location = HKHeartRateSensorLocation.Other
    // track current state of heart animation
    var heartIsSmall = false;
    // track initial size of heart
    var origHeartRect: CGRect!
    // heart beat duration
    var heartBeatDuration = 0.0
    
    // MARK: outlets
    @IBOutlet var deviceLabel : UILabel
    @IBOutlet var locationLabel : UILabel
    @IBOutlet var bpmLabel : UILabel
    @IBOutlet var heartImageView: UIImageView
    
    // MARK: UIViewController overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        println("viewDidLoad thread = \(NSThread.currentThread()) queue = \(dispatch_get_current_queue())")
        origHeartRect = heartImageView.frame
        // init the Bluetooth device manager
        _deviceManager = BTDeviceManager()
        _deviceManager.delegate = self
        // get HealthKit up and running
        requestHealthKitSharing()
        animateHeart()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: Implementation
    
    func requestHealthKitSharing() {
        // make sure HealthKit is available on this device
        if (!HKHealthStore.isHealthDataAvailable()) {
            return
        }
        // get our types to read and write for sharing permissions
        let typesToWrite = dataTypesToWrite()
        let typesToRead = dataTypesToRead()
        // create our health store
        let myHealthStore = HKHealthStore()
        
        // illustrate a few ways of handling the closure
        // maximum verbosity
        // request permissions to share health data with HealthKit
        println("requesting authorization to share health data types")
        myHealthStore.requestAuthorizationToShareTypes(typesToWrite, readTypes: typesToRead, completion: {
            (success: Bool, error: NSError!) -> Void in
            if success {
                println("successfully registered to share types")
                // all is good, so save our HealthStore and do some initialization
                self.healthStore = myHealthStore
                self.initHealthKit()
            } else if (error) {
                println("error regisering shared types = \(error)")
            }
        })
        
//        // drop return type
//        healthStore.requestAuthorizationToShareTypes(typesToWrite, readTypes: typesToRead, completion: {
//            (success: Bool, error: NSError!) in
//            if success {
//                println("successfully registered to share types")
//            } else if (error) {
//                println("error regisering shared types = \(error)")
//            }
//        })
//
//        // drop parameter types
//        healthStore.requestAuthorizationToShareTypes(typesToWrite, readTypes: typesToRead, completion: {
//            (success, error) in
//            if success {
//                println("successfully registered to share types")
//            } else if (error) {
//                println("error regisering shared types = \(error)")
//            }
//        })
//
//        // switch to trailing closure - you can do this if the last param is a closure
//        healthStore.requestAuthorizationToShareTypes(typesToWrite, readTypes: typesToRead) { (success: Bool, error: NSError!) -> Void in
//            if success {
//                println("successfully registered to share types")
//            } else if (error) {
//                println("error regisering shared types = \(error)")
//            }
//        }
//
//        // trailing closue with no return type and no param types
//        healthStore.requestAuthorizationToShareTypes(typesToWrite, readTypes: typesToRead) { (success, error) in
//            if success {
//                println("successfully registered to share types")
//            } else if (error) {
//                println("error regisering shared types = \(error)")
//            }
//        }
//        // trailing closue with no return type and no params
//        healthStore.requestAuthorizationToShareTypes(typesToWrite, readTypes: typesToRead) {
//            if $0 {
//                println("successfully registered to share types")
//            } else if ($1) {
//                println("error regisering shared types = \($1)")
//            }
//        }
//
//        // create a variable to hold the closure
//        let completion:((success: Bool, error: NSError!) -> Void) = { (success: Bool, error: NSError!) in
//            if success {
//                println("successfully registered to share types")
//            } else if (error) {
//                println("error regisering shared types = \(error)")
//            }
//        }
//        healthStore.requestAuthorizationToShareTypes(typesToWrite, readTypes: typesToRead, completion: completion)
    }
    
    func dataTypesToWrite() -> NSSet {
        let heartRateType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)
        let types = NSSet(object: heartRateType)
        return types;
    }
    
    func dataTypesToRead() -> NSSet {
        let heartRateType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)
        let types = NSSet(object: heartRateType)
        return types;
    }

    func initHealthKit() {
        // check for presence of HealthKit with optional binding statement
        if let myHealthStore = healthStore {
            // get heart rate quantity type
            let heartRateType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)
            // put together a query that will call closure when heart rate value has been updated
            let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { // trailing closure
                (query: HKObserverQuery!, handler: HKObserverQueryCompletionHandler!, error: NSError!) in
                //println("\(__FUNCTION__) thread = \(NSThread.currentThread()) queue = \(dispatch_get_current_queue())")
                if (error) {
                    println("observer query returned error = \(error)")
                } else {
                    // now let's go get the latest heart rate sample - use the end date and get in reverse chronological order
                    let endDate = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                    let sortDescriptors = NSArray(object: endDate)
                    // build up sampple query
                    let sampleQuery = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: sortDescriptors) { // trailing closure
                        (query: HKSampleQuery!, object: AnyObject[]!, error: NSError!) in
                        if (error) {
                            println("sample query returned error = \(error)")
                        } else {
                            // we are assume if the query succeeded that we got a value, not sure if this assumption
                            // is valid considering there is no documentation
                            let sample = object[0] as HKQuantitySample
                            println("sample = \(sample)")
                            // ignore old samples
                            let startDate = sample.startDate;
                            if (NSDate.date().timeIntervalSinceDate(startDate) < self.oldReadingTime) {
                                dispatch_async(dispatch_get_main_queue()) {
                                    // retreve value from sample
                                    if let quantity = sample.quantity {
                                        let value = quantity.doubleValueForUnit(self.heartRateUnit)
                                        self.heartBeatDuration = 60.0 / value;
                                        self.updateBPM(UInt16(value))
                                    }
                                    // retrieve source from sample
                                    if let name = sample.source?.name {
                                        self.updateDeviceName(name)
                                    }
                                    // retrieve meta data from sample - sensor location
                                    if let meta = sample.metadata {
                                        if let location = meta.objectForKey(HKMetadataKeyHeartRateSensorLocation) as NSNumber! {
                                            if let sensorLocation = HKHeartRateSensorLocation.fromRaw(location.integerValue) {
                                                self.updateLocation(sensorLocation)
                                                println("location = \(sensorLocation.toRaw())")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    myHealthStore.executeQuery(sampleQuery)
                }
            }
            myHealthStore.executeQuery(query)
        }
    }
        
    func updateDeviceName(deviceName: String) {
        if (deviceName != deviceLabel.text){
            deviceLabel.text = deviceName;
        }
    }
    
    func updateLocation(location: HKHeartRateSensorLocation) {
        if (location != self.location) {
            self.location = location;
            var locationString: String
            switch (location) {
            case .Other:
                locationString = "Other"
            case .Chest:
                locationString = "Chest"
            case .Wrist:
                locationString = "Wrist"
            case .Finger:
                locationString = "Finger"
            case .Hand:
                locationString = "Hand"
            case .EarLobe:
                locationString = "Ear Lobe"
            case .Foot:
                locationString = "Foot"
            default:
                locationString = "Reserved"
            }
            locationLabel.text = locationString
        }
    }
    
    func updateBPM(bpm: UInt16) {
        bpmLabel.text = String(bpm)
    }
    
    // This method is called once and the expectation is that it will
    // keep calling itself forever
    func animateHeart() {
        if (heartBeatDuration == 0.0) {
            // nothing happening, so check later in half a second
            heartImageView.frame = origHeartRect
            updateBPM(0)
            NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: Selector("animateHeart"), userInfo: nil, repeats: false)
            return;
        }
        // animate the heart
        let animation:(() -> Void) = {
            var newHeartRect = self.origHeartRect
            if (!self.heartIsSmall) {
                newHeartRect = CGRectInset(newHeartRect, 20, 20)
            }
            self.heartIsSmall = !self.heartIsSmall
            self.heartImageView.frame = newHeartRect
        }
        let completion:((Bool) -> Void) = { (Bool finished) in
            //println("animation complete")
            self.animateHeart()
        }
        let duration = heartBeatDuration == 0.0 ? 0.5 : (heartBeatDuration/2.0)
        UIView.animateWithDuration(heartBeatDuration/2.0, animations: animation, completion: completion)
    }
    
    // MARK: BTDeviceManagerDelegate
    
    func newBluetoothState(blueToothOn: Bool, blueToothState: String) {
        println("blueToothOn = \(blueToothOn) blueToothState = \(blueToothState)")
        if (!blueToothOn) {
            heartBeatDuration = 0.0
            updateDeviceName("No device connected")
        }
    }
    
    func deviceConnected(deviceName: String) {
        updateDeviceName(deviceName)
    }
    
    func deviceDisconnected() {
        heartBeatDuration = 0.0
        updateDeviceName("No device connected")
    }
    
    func newLocation(location: Int) {
        if let newSensorLocation = HKHeartRateSensorLocation.fromRaw(location) {
            deviceSensorLocation = newSensorLocation
        }
    }
    
    func newBPM(bpm: UInt16) {
        // check for presence of HealthKit with optional binding statement
        if let myHealthStore = healthStore {
            // sometimes we get 2 readings in a row at the same time, debounce those
            let now = NSDate()
            let timeSinceLastReading = now.timeIntervalSinceDate(lastReadingTime)
            lastReadingTime = now;
            if (timeSinceLastReading > minTimeBetweenReadings) {
                // build up the heart rate sample
                let heartRateType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)
                let heartRateQuantity = HKQuantity(unit: heartRateUnit, doubleValue: Double(bpm))
                let location = NSNumber(integer: deviceSensorLocation.toRaw())
                let meta = NSDictionary(object: deviceSensorLocation.toRaw(), forKey: HKMetadataKeyHeartRateSensorLocation)
                let heartRateSample = HKQuantitySample(type: heartRateType, quantity: heartRateQuantity, startDate: now, endDate: now, metadata: meta)
                
                myHealthStore.saveObject(heartRateSample) { (success: Bool, error: NSError!) -> Void in
                    if (success) {
                        println("successfully saved heart rate sample to HealthKit")
                    } else if (error) {
                        println("error saving heart rate sample to HealthKit = \(error)")
                    }
                }
            }
        } else {
            bpmLabel.text = String(bpm)
        }
     }
    
    // MARK: Action Handlers
    
    @IBAction func scanClicked(sender : AnyObject) {
        _deviceManager.startScan()
    }
    
    @IBAction func findClicked(sender : AnyObject) {
        _deviceManager.findDevice()
    }
}

