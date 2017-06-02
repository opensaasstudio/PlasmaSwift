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

    private var client: PlasmaClient?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let client = try! PlasmaClient(host: "localhost", port: 50051)
        
        client.connect() { (result, payload, error) -> Void in
            if let err = error {
                self.label.text = err.localizedDescription
            } else {
                self.label.text = payload?.data_p
            }
        }
        self.client = client
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var inputEventType: UITextField!
    
    
    @IBAction func subscribe(_ sender: Any) {
        if (self.inputEventType.text?.isEmpty)! {
            self.label.text = "eventType is not specified"
        } else {
            client?.subscribe(eventTypes: [self.inputEventType.text!])
        }
    }
    
    @IBAction func close(_ sender: Any) {
        client?.shutdown()
        self.label.text = "closed connection"
    }
    
}

