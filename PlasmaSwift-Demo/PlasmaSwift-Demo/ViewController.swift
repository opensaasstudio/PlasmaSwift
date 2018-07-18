import UIKit
import PlasmaSwift

final class ViewController: UIViewController {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var inputEventType: UITextField!

    private var connection: PlasmaClient.Connection?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let connection = PlasmaClient(host: "localhost", port: 50051).connect(retryCount: 10) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .next(let payload):
                    self?.label.text = payload.data

                case .error(let error):
                    self?.label.text = error.localizedDescription
                }
            }
        }
        self.connection = connection
    }

    @IBAction func subscribe(_ sender: Any) {
        if (inputEventType.text?.isEmpty)! {
            label.text = "eventType is not specified"
        } else {
            connection?.subscribe(eventTypes: [inputEventType.text!])
        }
    }
    
    @IBAction func close(_ sender: Any) {
        connection?.shutdown()
        label.text = "closed connection"
    }
}
