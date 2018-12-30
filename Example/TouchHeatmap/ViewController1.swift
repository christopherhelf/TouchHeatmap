//
//  ViewController.swift
//  TouchHeatmap
//
//  Created by Christopher Helf on 26.09.15.
//  Copyright © 2015 Christopher Helf. All rights reserved.
//

import UIKit

class ViewController1: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.gray
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        self.view.addGestureRecognizer(tap)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func tap(_ recognizer: UIGestureRecognizer) {
        print("tap")
    }


}



