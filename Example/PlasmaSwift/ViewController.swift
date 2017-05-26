//
//  ViewController.swift
//  PlasmaSwift
//
//  Created by stormcat24 on 05/12/2017.
//  Copyright (c) 2017 stormcat24. All rights reserved.
//

import UIKit
import PlasmaSwift

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var inputEventType: UITextField!
    
    @IBAction func connect(_ sender: Any) {
        
        if (self.inputEventType.text?.isEmpty)! {
            self.label.text = "eventType is not specified"
        } else {
            let client = PlasmaClient(host: "localhost", port: 50051)
            
            do {
                try client.subscribe(eventTypes: [self.inputEventType.text!]) { (result, payload, error) -> Void in
                    if let err = error {
                        self.label.text = err.localizedDescription
                    } else {
                        self.label.text = payload?.data_p
                    }
                }
            } catch let error {
                print(error)
            }
        }
    }
    
}

