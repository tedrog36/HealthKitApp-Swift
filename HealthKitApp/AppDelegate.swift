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
    
    // delay for initing HealthKit after all view controllers are constructed
    let kInitHealthKitDelay = 0.5
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

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
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
        
        // illustrate a few ways of handling the closure
        // maximum verbosity
        // request permissions to share health data with HealthKit
        print("requesting authorization to share health data types")
        myHealthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { (success: Bool, error: Error?) in
            if success {
                print("successfully registered to share types")
                // all is good, so save our HealthStore and do some initialization
                self.healthStore = myHealthStore
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: Constants.kHealthKitInitialized), object: self)
                //self.initHealthKit()
            } else if let theError = error {
                print("error regisering shared types = \(theError)")
            }
        
        }
        
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

