//
//  PKLocationManager.swift
//  PKLocationManager
//
//  Created by Philip Kluz on 6/20/14.
//  Copyright (c) 2014 NSExceptional. All rights reserved.
//

import Foundation
import CoreLocation

@objc public class LocationManager: NSObject, CLLocationManagerDelegate {
    
    /// Shared PKLocationManager instance.
    public class var sharedManager: LocationManager {
        return Constants.sharedManager
    }
    
    required public override init() {
        super.init()
        
        sharedLocationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        sharedLocationManager.delegate = self
    }
    
    /// Adds an object to a list of objects interested in aquiring location updates. Note that the updates might be deferred.
    public func register(locationMonitor monitoringObject:AnyObject!, desiredAccuracy: CLLocationAccuracy, queue: dispatch_queue_t, handler:(location: CLLocation) -> ()) -> (success: Bool, error: NSError?) {
        if !isLocationMonitoringAvailable {
            return (false, NSError(domain: "com.NSExceptional.PKLocationManager", code: 0, userInfo: [NSLocalizedDescriptionKey : "Location monitoring unavailable." ]))
        }
        
        var presentMonitor = self.locationMonitorFor(monitoringObject)
        
        if (presentMonitor != nil) {
            return (false, NSError(domain: "com.NSExceptional.PKLocationManager", code: 1, userInfo: [NSLocalizedDescriptionKey : "Object is already registered as a location monitor." ]))
        }
        
        var monitor = LocationMonitor(monitoringObject: monitoringObject, queue: queue, desiredAccuracy: desiredAccuracy, handler: handler)
        
        monitors.append(monitor)
        sharedLocationManager.desiredAccuracy = accuracy
        
        if monitors.count > 0 {
            sharedLocationManager.startUpdatingLocation()
        }
        
        return (true, nil)
    }
    
    
    /// Adds an object to a list of objects interested in aquiring location updates. Note that the updates might be deferred.
    public func register(locationMonitor monitoringObject:AnyObject!, desiredAccuracy: CLLocationAccuracy, handler:(location: CLLocation) -> ()) -> (success: Bool, error: NSError?) {
        return register(locationMonitor: monitoringObject, desiredAccuracy: desiredAccuracy, queue: dispatch_get_main_queue(), handler: handler)
    }
    
    /// OBJETIVE-C COMPATIBILITY METHOD - Adds an object to a list of objects interested in aquiring location updates. Note that the updates might be deferred.
    public func register(locationMonitor monitoringObject:AnyObject!, desiredAccuracy: CLLocationAccuracy, queue: dispatch_queue_t, errorPtr: NSErrorPointer, handler:(location: CLLocation) -> ()) -> Bool {
        let (success, error) = register(locationMonitor: monitoringObject, desiredAccuracy: desiredAccuracy, queue: queue, handler: handler);
        
        if (errorPtr != nil) {
            errorPtr.memory = error
            return false
        }
        
        return true
    }
    
    /// OBJETIVE-C COMPATIBILITY METHOD - Adds an object to a list of objects interested in aquiring location updates. Note that the updates might be deferred.
    public func register(locationMonitor monitoringObject:AnyObject!, desiredAccuracy: CLLocationAccuracy, errorPtr: NSErrorPointer, handler:(location: CLLocation) -> ()) -> Bool {
        return register(locationMonitor: monitoringObject, desiredAccuracy: desiredAccuracy, queue: dispatch_get_main_queue(), errorPtr: errorPtr, handler: handler)
    }
    
    /// Removes an object from the list of objects registered for location updates.
    public func deregister(locationMonitor:AnyObject!) {
        monitors = monitors.filter { element in
            return element.monitoringObject !== locationMonitor;
        }
        
        sharedLocationManager.desiredAccuracy = accuracy
        
        if monitors.count == 0 {
            sharedLocationManager.stopUpdatingLocation()
        }
    }
    
    /// Determines whether location monitoring is currently active.
    public var isLocationMonitoringActive: Bool {
        return monitors.count > 0
    }
    
    /// Determines whether location monitoring is available.
    public var isLocationMonitoringAvailable: Bool {
        return CLLocationManager.locationServicesEnabled()
    }
    
    private var _requiresLocationMonitoringWhenInUse: Bool = false
    
    /// If set to 'true' the user will be prompted by the system and asked to grant location access permissions while the application is in use (foreground). Please note that you will need to provide a value for the 'NSLocationWhenInUseUsageDescription' key in your application's 'Info.plist' file.
    public var requiresLocationMonitoringWhenInUse: Bool {
        get {
            return _requiresLocationMonitoringWhenInUse
        }
        set {
            if newValue {
                sharedLocationManager.requestWhenInUseAuthorization()
            }
        }
    }
    
    private var _requiresLocationMonitoringAlways: Bool = false
    /// If set to 'true' the user will be prompted by the system and asked to grant location access permissions, which will also work if the application were to be in the background. Please note that you will need to provide a value for the 'NSLocationAlwaysUsageDescription' key in you application's 'Info.plist' file.
    public var requiresLocationMonitoringAlways: Bool {
        get {
            return _requiresLocationMonitoringAlways
        }
        set {
            if newValue {
                sharedLocationManager.requestAlwaysAuthorization()
            }
        }
    }
    
    /// Returns 'true' if the user denied location access permissions, 'false' otherwise.
    public var isLocationMonitoringPermissionDenied: Bool {
        return CLLocationManager.authorizationStatus() == CLAuthorizationStatus.Denied
    }
    
    /// Returns 'true' if the user granted location access permissions while the application is in use (foreground), 'false' otherwise.
    public var isLocationMonitoringPermittedWhenInUse: Bool {
        return CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedWhenInUse
    }
    
    /// Returns 'true' if the user granted location access permissions, independent of the application's state (foreground + background), 'false' otherwise.
    public var isLocationMonitoringAlwaysPermitted: Bool {
        return CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedAlways
    }
    
    /// Computes the accuracy for the location manager, which is equal to the most precise accuracy requested by one of the monitoring objects.
    public var accuracy: CLLocationAccuracy {
        return monitors.reduce(kCLLocationAccuracyThreeKilometers) { current, next in
            return next.desiredAccuracy <= current ? next.desiredAccuracy : current
        }
    }
    
    /// Returns the monitor wrapper object for a given existing monitoring object.
    private func locationMonitorFor(monitoringObject: AnyObject!) -> LocationMonitor? {
        for monitor in monitors {
            if monitor.monitoringObject === monitoringObject {
                return monitor
            }
        }
        
        return nil
    }
    
    // #MARK: CLLocationManagerDelegate
    
    public func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        for location in locations as Array<CLLocation> {
            for monitor in monitors {
                monitor.handler?(location)
            }
        }
    }
    
    public func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        var permissionGiven = status == CLAuthorizationStatus.AuthorizedAlways || status == CLAuthorizationStatus.AuthorizedWhenInUse
        if permissionGiven && monitors.count > 0 {
            sharedLocationManager.startUpdatingLocation()
        }
    }

    // #MARK: Private

    private struct Constants {
        static let sharedManager = LocationManager()
    }
    
    private let sharedLocationManager = CLLocationManager()
    private var monitors = [LocationMonitor]()
}
