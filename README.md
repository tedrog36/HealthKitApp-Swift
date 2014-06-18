HealthKitApp-Swift
==================
This is a sample application that communicates with a heart rate monitor via CoreBlueTooth and pushes heart rate
information to HealthKit.  It doesn't required a connection to the heart rate monitor, it will retreive heart rate
information from HealthKit to display if HK is paired with your heart rate monitor.

I wrote this app to learn Swift and provide examples for others as well as myself for various Swift language
constructs.  Of course, I wanted to learn HealthKit as well.

In this app you will find:

1. Many examples of closures.  For one closure, in ViewController.swift, I provided 7 different closure solutions.

2. Use of optionals - normal and implicitly unwrapped

3. Use of constants and properties

4. Outlets and actions

5. Custom delegate

6. Requesting permissions from HealthKit

7. Use of HealthKit to store and retreive heart rate data

To run this app:

1. Create your own bundle id

2. Create an app id with the HealthKit entitlement selected

3. You'll need a heart rate monitor - I tested this with the 60Beat heart monitor

