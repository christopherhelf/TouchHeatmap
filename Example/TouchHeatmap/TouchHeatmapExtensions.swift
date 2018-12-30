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

public protocol SwizzlingInjection: class {
    static func inject()
}

class SwizzlingHelper {
    
    private static let doOnce: Any? = {
        UIViewController.inject()
        return nil
    }()
    
    static func enableInjection() {
        _ = SwizzlingHelper.doOnce
    }
}

extension UIApplication {
    
    override open var next: UIResponder? {
        // Called before applicationDidFinishLaunching
        SwizzlingHelper.enableInjection()
        return super.next
    }
    
    // Here we exchange the implementations
    func swizzleSendEvent() {
        let original = class_getInstanceMethod(object_getClass(self), #selector(UIApplication.sendEvent(_:)))
        let swizzled = class_getInstanceMethod(object_getClass(self), #selector(self.sendEventTracked(_:)))
        method_exchangeImplementations(original!, swizzled!);
    }
    
    // The new method, where we also send touch events to the TouchHeatmap Singleton
    @objc func sendEventTracked(_ event: UIEvent) {
        self.sendEventTracked(event)
        TouchHeatmap.sharedInstance.sendEvent(event: event)
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

extension UIViewController : SwizzlingInjection {
    // Reference for deprecates UIViewController initialize()
    // https://stackoverflow.com/questions/42824541/swift-3-1-deprecates-initialize-how-can-i-achieve-the-same-thing/42824542#_=_
    
    public static func inject() {
        // make sure this isn't a subclass
        guard self === UIViewController.self else { return }
        
        let originalSelector = #selector(UIViewController.viewDidAppear(_:))
        let swizzledSelector = #selector(viewDidAppearTracked(_:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
        
        let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod!), method_getTypeEncoding(swizzledMethod!))
        
        if didAddMethod {
            class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod!), method_getTypeEncoding(originalMethod!))
        } else {
            method_exchangeImplementations(originalMethod!, swizzledMethod!);
        }
    }
    
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
                return String.init(describing: self.classForCoder)
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
    
    // The method where we are tracking
    @objc func viewDidAppearTracked(_ animated: Bool) {
        self.viewDidAppearTracked(animated)
        TouchHeatmap.sharedInstance.viewDidAppear(name: self.touchHeatmapKey)
    }
    
}


