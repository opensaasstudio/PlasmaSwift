import UIKit
import PlasmaSwift

final class ViewController: UIViewController {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var inputEventType: UITextField!

    private var connection: PlasmaClient.Connection?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        PlasmaClient.useInsecureConnections(forHost: "localhost:50051")
        
        let connection = PlasmaClient(host: "localhost", port: 50051).connect { [weak self] (result, payload, error) in
            DispatchQueue.main.async {
                if let err = error {
                    self?.label.text = err.localizedDescription
                } else {
                    self?.label.text = payload?.data_p
                }
            }
        }
        self.connection = connection
    }

    @IBAction func subscribe(_ sender: Any) {
        if (inputEventType.text?.isEmpty)! {
            label.text = "eventType is not specified"
        } else {
            connection?.subscribe(types: [inputEventType.text!])
        }
    }
    
    @IBAction func close(_ sender: Any) {
        connection?.shutdown()
        label.text = "closed connection"
    }
}
