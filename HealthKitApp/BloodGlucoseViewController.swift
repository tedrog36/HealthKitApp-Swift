//
//  BloodGlucoseViewController.swift
//  HealthKitApp
//
//  Created by Ted Rogers on 7/1/14.
//  Copyright (c) 2014 Ted Rogers Consulting, LLC. All rights reserved.
//

import UIKit
import HealthKit

class BloodGlucoseViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    let bloodGlucoseUnitString = "mg/dL"
    let bloodGlucoseUnit = HKUnit(fromString: "mg/dL") // or HKUnit.countUnit().unitDividedByUnit(HKUnit.minuteUnit())
    // blood glucose metadata meal
    let myHKMetadataKeyBloodGlucoseWhen = "com.tedmrogers.HealthKitApp.When"
    let myHKMetadataValueBloodGlucoseWhenMorning = "Morning"
    let myHKMetadataValueBloodGlucoseWhenPreMeal = "Pre-Meal"
    let myHKMetadataValueBloodGlucoseWhenPostMeal = "Post-Meal"
    let myHKMetadataValueBloodGlucoseWhenNight = "Night"
    // blood glucose metadata notes
    let myHKMetadataKeyBloodGlucoseNotes = "com.tedmrogers.HealthKitApp.Notes"
    let kBloodGlucoseCellIdentifier = "BloodGlucoseIdentifier"

    // the list of glucose samples
    var _bloodGlucoseSamples:AnyObject[]?   // optional
    var _dateFormatter:NSDateFormatter!     // implicitly unwrapped optional - use these when they should never be null after initialization
    
    // MARK: Outlets
    @IBOutlet var tableView: UITableView
    
    override func viewDidLoad() {
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        if let myHealthStore = appDelegate.healthStore {
            self.initHealthKit()
        } else {
            // wait for notifiication that HealthKit is ready
            NSNotificationCenter.defaultCenter().addObserverForName(Constants.kHealthKitInitialized, object: nil, queue: nil) { (notif: NSNotification!) -> Void in
                // make no assumptions about current queue
                dispatch_async(dispatch_get_main_queue()) {
                    self.initHealthKit()
                }
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        println("tableView height = \(tableView.frame.height)")
    }
    
    // MARK: Implementation
    
    func initHealthKit() {
        // check for presence of HealthKit with optional binding statement
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        if let myHealthStore = appDelegate.healthStore {
            // now let's go get the latest heart rate sample - use the end date and get in reverse chronological order
            let endDate = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let sortDescriptors = NSArray(object: endDate)
            let bloodGlucoseType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)
            // build up sampple query
             let sampleQuery = HKSampleQuery(sampleType: bloodGlucoseType, predicate: nil, limit: Int(HKObjectQueryNoLimit), sortDescriptors: sortDescriptors) { // trailing closure
                (query: HKSampleQuery!, objects: AnyObject[]!, error: NSError!) in
                if (error) {
                    println("sample query returned error = \(error)")
                } else if (objects.count > 0) {
                     dispatch_async(dispatch_get_main_queue()) {
                        self._bloodGlucoseSamples = objects;
                        self.tableView.reloadData()
                    }
                } else {
                    println("got no samples back")
                }
            }
            myHealthStore.executeQuery(sampleQuery)
        }
    }
    
    func addBloodGlucoseReading(when: String!, notes: String!, reading: Double) {
        // check for presence of HealthKit with optional binding statement
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        if let myHealthStore = appDelegate.healthStore {
            let now = NSDate()
            let bloodGlucoseType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)
            let bloodGlucoseQuantity = HKQuantity(unit: bloodGlucoseUnit, doubleValue: reading)
            var meta = NSMutableDictionary()
            if (when) {
                meta.setValue(when, forKey: myHKMetadataKeyBloodGlucoseWhen)
            }
            if (notes) {
                meta.setValue(notes, forKey: myHKMetadataKeyBloodGlucoseNotes)
            }
            
            let bloodGlucoseSample = HKQuantitySample(type: bloodGlucoseType, quantity: bloodGlucoseQuantity, startDate: now, endDate: now, metadata: meta)
            
            myHealthStore.saveObject(bloodGlucoseSample) { (success: Bool, error: NSError!) -> Void in
                if (success) {
                    println("successfully saved blood glucose reading to HealthKit")
                } else if (error) {
                    println("error saving blood glucose reading to HealthKit = \(error)")
                }
                dispatch_async(dispatch_get_main_queue()) {
                    if (self._bloodGlucoseSamples) {
                        var samplesArray = self._bloodGlucoseSamples!
                        samplesArray.insert(bloodGlucoseSample, atIndex: 0) // this action creates a new array
                        self._bloodGlucoseSamples = samplesArray // this is now our new array
                        println("samplesArray = \(samplesArray.count) _bloodGlucoseSamples = \(self._bloodGlucoseSamples!.count)")
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
    
    // MARK: UITableViewDataSource
    
    func numberOfSectionsInTableView(tableView: UITableView!) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        var rows = 0;
        if let samples = _bloodGlucoseSamples {
            rows = samples.count
        }
        return rows
    }
    
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let row = indexPath.row
        var cell = tableView.dequeueReusableCellWithIdentifier(kBloodGlucoseCellIdentifier) as UITableViewCell!
        if (!cell) {
            cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: kBloodGlucoseCellIdentifier)
        }
        // we shouldn't get here unless _bloodGlucoseSamples is valid so "force" unwrap
        let sample = _bloodGlucoseSamples![row] as HKQuantitySample
        
        var valueText = ""
        var whenText = ""
        // retreve value from sample
        if let quantity = sample.quantity {
            let value = Int(quantity.doubleValueForUnit(self.bloodGlucoseUnit))
            valueText = String(value) + bloodGlucoseUnitString
        }
        // retrieve the start date
        if let startDate = sample.startDate {
            whenText += NSDateFormatter.localizedStringFromDate(startDate, dateStyle: NSDateFormatterStyle.ShortStyle, timeStyle: NSDateFormatterStyle.ShortStyle)
        }
        // retrieve meta data from sample - when
        if let meta = sample.metadata {
            // notice syntax below optional form of type cast.  We need this since metadata is optional
            if let when = meta.objectForKey(myHKMetadataKeyBloodGlucoseWhen) as? String {
                whenText += " (\(when))"
            }
        }
       // populate the cell
        cell.textLabel.text = valueText
        cell.detailTextLabel.text = whenText
        
        return cell
    }
    
    // MARK: UITableViewDelegate
    
    func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        
    }
    
    // MARK: Action Handlers
    
    @IBAction func clickedAdd(sender: AnyObject) {
        addBloodGlucoseReading(myHKMetadataValueBloodGlucoseWhenPostMeal, notes: nil, reading: 84)
    }
}
