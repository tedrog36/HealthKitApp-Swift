//
//  ViewController.swift
//  HealthKitApp
//
//  Created by Ted Rogers on 6/10/14.
//  Copyright (c) 2014 Ted Rogers Consulting, LLC. All rights reserved.
//

import UIKit
import HealthKit

class HeartRateViewController: UIViewController, BTDeviceManagerDelegate {
    // MARK: Contants
    let minTimeBetweenReadings: TimeInterval = 0.200  // value to debounce repeated readings from BT device
    let oldReadingTime: TimeInterval = 30             // readings older than this are discarded
    let heartRateUnit = HKUnit(from: "count/min") // or HKUnit.countUnit().unitDividedByUnit(HKUnit.minuteUnit())
    
    // MARK: properties
    // the bluetooth device manager object
    var deviceManager: BTDeviceManager!    // implicitly unwrapped optional
    // track time of last reading.  My heart rate monitor is providing two readings back to back
    // so this is the drop one on the floor
    var lastReadingTime = Date.distantPast
    // the device sensor location from the devcie mananger
    var deviceSensorLocation = HKHeartRateSensorLocation.other
    // the device sensor location returned from HealthKit
    var location = HKHeartRateSensorLocation.other
    // track current state of heart animation
    var heartIsSmall = false;
    // track initial size of heart
    var origHeartRect: CGRect!
    // heart beat duration
    var heartBeatDuration = 0.0
    
    // MARK: outlets
    @IBOutlet var deviceLabel : UILabel!
    @IBOutlet var locationLabel : UILabel!
    @IBOutlet var bpmLabel : UILabel!
    @IBOutlet var heartImageView: UIImageView!
    
    // MARK: UIViewController overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad thread = \(Thread.current)")
        // init the Bluetooth device manager
        deviceManager = BTDeviceManager()
        deviceManager.delegate = self
        let appDelegate = UIApplication.shared.delegate as! AppDelegate // forced type cast
        // check for presence of HealthKit with optional binding statement
        if let healthStore = appDelegate.healthStore {
            self.initHealthKit(healthStore: healthStore)
            self.startHeartAnimation()
        } else {
            // wait for notifiication that HealthKit is ready
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: Constants.kHealthKitInitialized), object: nil, queue: nil) { (notif: Notification!) -> Void in
                self.initHealthKit(healthStore: appDelegate.healthStore!)  // force unwrap becuase it must exist
                self.startHeartAnimation()
            }
        }
    }

    // MARK: Implementation
    
    func initHealthKit(healthStore: HKHealthStore) {
        // get heart rate quantity type
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            return
        }
        // put together a query that will call closure when heart rate value has been updated
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { (query: HKObserverQuery, handler: HKObserverQueryCompletionHandler, error: Error?) in
            if let theError = error {
                print("observer query returned error = \(theError.localizedDescription)")
            } else {
                // now let's go get the latest heart rate sample - use the end date and get in reverse chronological order
                let endDateSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                let sortDescriptors = [endDateSortDescriptor]
                // build up sampple query
                let sampleQuery = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: sortDescriptors, resultsHandler: {
                    (query: HKSampleQuery, querySamples:[HKSample]?, error: Error?) in
                    if let theError = error {
                        print("sample query returned error = \(theError)")
                    } else if let samples = querySamples, samples.count > 0 { // multi-clause condition
                        let sample = samples[0] as! HKQuantitySample
                        print("sample = \(sample)")
                        // ignore old samples
                         if (NSDate().timeIntervalSince(sample.startDate) < self.oldReadingTime) {
                            DispatchQueue.main.async() {
                                // retreve value from sample
                                let value = sample.quantity.doubleValue(for: self.heartRateUnit)
                                self.heartBeatDuration = 60.0 / value;
                                self.updateBPM(UInt16(value))
                                // retrieve meta data from sample - sensor location
                                if let metadata = sample.metadata {
                                    if let location = metadata[HKMetadataKeyHeartRateSensorLocation] as? NSNumber {
                                        if let sensorLocation = HKHeartRateSensorLocation(rawValue: location.intValue) {
                                            self.updateLocation(sensorLocation)
                                            print("location = \(sensorLocation.rawValue)")
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        print("got no samples back")
                    }
                })
                healthStore.execute(sampleQuery)
            }
        }
        healthStore.execute(query)
    }
    
    func updateDeviceName(_ deviceName: String) {
        if (deviceName != deviceLabel.text){
            deviceLabel.text = deviceName;
        }
    }
    
    func updateLocation(_ location: HKHeartRateSensorLocation) {
        if (location != self.location) {
            self.location = location;
            var locationString: String
            switch (location) {
            case .other:
                locationString = "Other"
            case .chest:
                locationString = "Chest"
            case .wrist:
                locationString = "Wrist"
            case .finger:
                locationString = "Finger"
            case .hand:
                locationString = "Hand"
            case .earLobe:
                locationString = "Ear Lobe"
            case .foot:
                locationString = "Foot"
            }
            locationLabel.text = locationString
        }
    }
    
    func updateBPM(_ bpm: UInt16) {
        bpmLabel.text = String(bpm)
    }
    
    func startHeartAnimation() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+2) {
            self.origHeartRect = self.heartImageView.frame
            self.animateHeart()
        }
    }
    
    // This method is called once and the expectation is that it will
    // keep calling itself forever
    func animateHeart() {
//        print("heartBeatDuration = \(heartBeatDuration)")
        if (heartBeatDuration == 0.0) {
            // nothing happening, so check later in half a second
            heartImageView.frame = origHeartRect
            updateBPM(0)
            Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(HeartRateViewController.animateHeart), userInfo: nil, repeats: false)
            return;
        }
        // animate the heart
        let animation:(() -> Void) = {
            var newHeartRect = self.origHeartRect!   // in this case you must force unwrap the implicitly unwrapped optional
            self.heartIsSmall = !self.heartIsSmall
            if (self.heartIsSmall) {
                newHeartRect = newHeartRect.insetBy(dx: 20, dy: 20)
            }
//             print("animtation to new size: w = \(newHeartRect.width) h = \(newHeartRect.height) heartIsSmall = \(self.heartIsSmall)")
            self.heartImageView.frame = newHeartRect
        }
        let completion:((Bool) -> Void) = { (finished) in
            //println("animation complete")
            self.animateHeart()
        }
        UIView.animate(withDuration: heartBeatDuration/2.0, animations: animation, completion: completion)
    }
    
    // MARK: BTDeviceManagerDelegate
    
    func newBluetoothState(_ blueToothOn: Bool, blueToothState: String) {
        print("blueToothOn = \(blueToothOn) blueToothState = \(blueToothState)")
        if (!blueToothOn) {
            heartBeatDuration = 0.0
            updateDeviceName("No device connected")
        }
    }
    
    func deviceConnected(_ deviceName: String) {
        updateDeviceName(deviceName)
    }
    
    func deviceDisconnected() {
        heartBeatDuration = 0.0
        updateDeviceName("No device connected")
    }
    
    func newLocation(_ location: Int) {
        if let newSensorLocation = HKHeartRateSensorLocation(rawValue: location) {
            deviceSensorLocation = newSensorLocation
        }
    }
    
    func newBPM(_ bpm: UInt16) {
        // check for presence of HealthKit with optional binding statement
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if let healthStore = appDelegate.healthStore {
            // sometimes we get 2 readings in a row at the same time, debounce those
            let now = Date()
            let timeSinceLastReading = now.timeIntervalSince(lastReadingTime)
            lastReadingTime = now;
            if (timeSinceLastReading > minTimeBetweenReadings) {
                // build up the heart rate sample
                let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)
                let heartRateQuantity = HKQuantity(unit: heartRateUnit, doubleValue: Double(bpm))
                let location = NSNumber(value: deviceSensorLocation.rawValue)
                let meta = [HKMetadataKeyHeartRateSensorLocation: location]
                let heartRateSample = HKQuantitySample(type: heartRateType!, quantity: heartRateQuantity, start: now, end: now, metadata: meta)
                
                healthStore.save(heartRateSample) {
                    (success: Bool, error: Error?) in
                    if success {
                        print("successfully saved heart rate sample to HealthKit")
                    } else if let theError = error {
                        print("error saving heart rate sample to HealthKit = \(theError)")
                    }
                }
            }
        } else {
            bpmLabel.text = String(bpm)
            self.heartBeatDuration = 60.0 / Double(bpm);
        }
     }
    
    // MARK: Action Handlers
    
    @IBAction func scanClicked(_ sender : AnyObject) {
        deviceManager.startScan()
    }
    
    @IBAction func findClicked(_ sender : AnyObject) {
        deviceManager.findDevice()
    }
}

