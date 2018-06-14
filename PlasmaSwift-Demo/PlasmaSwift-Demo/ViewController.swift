import UIKit
import PlasmaSwift

class ViewController: UIViewController {
    
    private var connection: PlasmaClient.Connection?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        PlasmaClient.useInsecureConnections(forHost: "localhost:50051")
        
        let connection = PlasmaClient(host: "localhost", port: 50051)
            .connect { (result, payload, error) in
                if let err = error {
                    self.label.text = err.localizedDescription
                } else {
                    self.label.text = payload?.data_p
                }
        }
        self.connection = connection
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
            connection?.subscribe(types: [self.inputEventType.text!])
        }
    }
    
    @IBAction func close(_ sender: Any) {
        connection?.shutdown()
        self.label.text = "closed connection"
    }
    
}
