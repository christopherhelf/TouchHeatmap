//
//  TouchHeatmapExtensions.swift
//  TouchHeatmap
//
//  Created by Christopher Helf on 27.09.15.
//  Copyright © 2015 Christopher Helf. All rights reserved.
//

import Foundation
import UIKit

/** 

- UIApplication Extension
We exchange implementations of the sendEvent method in order to be able to capture 
all touches occurring within the application, the other option would be to subclass
UIApplication, which is however harder for users to setup

*/

extension UIApplication {
    
    // Here we exchange the implementations
    func swizzleSendEvent() {
        let original = class_getInstanceMethod(object_getClass(self), Selector("sendEvent:"))
        let swizzled = class_getInstanceMethod(object_getClass(self), Selector("sendEventTracked:"))
        method_exchangeImplementations(original, swizzled);
    }
    
    // The new method, where we also send touch events to the TouchHeatmap Singleton
    func sendEventTracked(event: UIEvent) {
        self.sendEventTracked(event)
        TouchHeatmap.sharedInstance.sendEvent(event)
    }
}

/**

- UIViewController Extension
In order to make screenshots and to manage the flows between Controllers,
we need to know when a screen was presented. We override the initialization 
function here and exchange implementations of the viewDidAppear method
In addition, we can add a name to a UIViewController so it's name is being
tracked more easily

*/

extension UIViewController {
    
    // The struct we storing for the controller's name
    private struct AssociatedKeys {
        static var DescriptiveName = "TouchHeatMapViewControllerKeyDefault"
    }
    
    // The variable that's set as the controller's name, default's to the classname
    var touchHeatmapKey: String {
        get {
            if let name = objc_getAssociatedObject(self, &AssociatedKeys.DescriptiveName) as? String {
                return name
            } else {
                return "\(self)"
            }
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.DescriptiveName,
                newValue as NSString?,
                objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    // Override of the initialization function
    public override class func initialize() {
        
        struct Static {
            static var token: dispatch_once_t = 0
        }
        
        // make sure this isn't a subclass
        if self !== UIViewController.self {
            return
        }
        
        // Make sure the swizzle is only done once
        dispatch_once(&Static.token) {
            
            let originalSelector = Selector("viewDidAppear:")
            let swizzledSelector = Selector("viewDidAppearTracked:")
            
            let originalMethod = class_getInstanceMethod(self, originalSelector)
            let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
            
            let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
            
            if didAddMethod {
                class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod);
            }
            
        }
    }
    
    // The method where we are tracking
    func viewDidAppearTracked(animated: Bool) {
        self.viewDidAppearTracked(animated)
        TouchHeatmap.sharedInstance.viewDidAppear(self.touchHeatmapKey)
    }
    
    
    
}


