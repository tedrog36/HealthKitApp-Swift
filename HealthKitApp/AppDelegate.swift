//
//  AppDelegate.swift
//  HealthKitApp
//
//  Created by Ted Rogers on 6/10/14.
//  Copyright (c) 2014 Ted Rogers Consulting, LLC. All rights reserved.
//

import UIKit
import HealthKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // the app main window
    var window: UIWindow?
    // the health store - can be null if we don't get permission
    var healthStore: HKHealthStore?         // optional

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool {
        // dispatch immediately after current block
        DispatchQueue.main.async {
            self.requestHealthKitSharing()
        }
        return true
    }

    func requestHealthKitSharing() {
        // make sure HealthKit is available on this device
        if !HKHealthStore.isHealthDataAvailable() {
            return
        }
        // get our types to read and write for sharing permissions
        let typesToWrite = dataTypesToWrite()
        let typesToRead = dataTypesToRead()
        // create our health store
        let myHealthStore = HKHealthStore()
        
        print("requesting authorization to share health data types")
        // illustrate a few ways of handling the closure
        // start with class trailing closure
        myHealthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { (success, error) in
            if success {
                self.handleAuthorizationSuccess(healthStore: myHealthStore)
            } else {
                self.handleAuthorizationFailure(error: error)
            }
        }

//        // maximum verbosity
//        // request permissions to share health data with HealthKit
//        myHealthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead, completion: {
//            (success: Bool, error: Error?) -> Void in
//            if success {
//                self.handleAuthorizationSuccess(healthStore: myHealthStore)
//            } else {
//                self.handleAuthorizationFailure(error: error)
//            }
//        })
//        // drop parameter types
//        myHealthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead, completion: {
//            (success, error) -> Void in
//            if success {
//                self.handleAuthorizationSuccess(healthStore: myHealthStore)
//            } else {
//                self.handleAuthorizationFailure(error: error)
//            }
//        })
//        // drop return
//        myHealthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead, completion: {
//            (success, error) in
//            if success {
//                self.handleAuthorizationSuccess(healthStore: myHealthStore)
//            } else {
//                self.handleAuthorizationFailure(error: error)
//            }
//        })
//        // switch to trailing closure - you can do this if the last param is a closure
//        myHealthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { (success: Bool, error: Error?) -> Void in
//            if success {
//                self.handleAuthorizationSuccess(healthStore: myHealthStore)
//            } else {
//                self.handleAuthorizationFailure(error: error)
//            }
//        }
//        // trailing closue with no return type and no param types
//        myHealthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { (success, error) in
//            if success {
//                self.handleAuthorizationSuccess(healthStore: myHealthStore)
//            } else {
//                self.handleAuthorizationFailure(error: error)
//            }
//        }
//        // trailing closue with no return type and no params
//        myHealthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) {
//            if $0 {
//                self.handleAuthorizationSuccess(healthStore: myHealthStore)
//            } else {
//                self.handleAuthorizationFailure(error: $1)
//            }
//        }
//        // create a variable to hold the closure
//        let completion = {
//            (success: Bool, error: Error?) -> Void in
//            if success {
//                self.handleAuthorizationSuccess(healthStore: myHealthStore)
//            } else {
//                self.handleAuthorizationFailure(error: error)
//            }
//        }
//        myHealthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead, completion: completion)
    }
    
    func handleAuthorizationSuccess(healthStore: HKHealthStore) {
        print("successfully registered to share types")
        // all is good, so save our HealthStore and do some initialization
        DispatchQueue.main.async {
            self.healthStore = healthStore
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: Constants.kHealthKitInitialized), object: self)
        }
    }
    
    func handleAuthorizationFailure(error: Error?) {
        if let theError = error {
            print("error regisering shared types = \(theError)")
        }
    }
    
    func dataTypesToWrite() -> Set<HKQuantityType> {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)
        let bloodGlucoseType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
        let types: Set = [heartRateType!, bloodGlucoseType!];
        return types;
    }
    
    func dataTypesToRead() -> Set<HKQuantityType> {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)
        let bloodGlucoseType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
        let types: Set = [heartRateType!, bloodGlucoseType!];
        return types;
    }
}

