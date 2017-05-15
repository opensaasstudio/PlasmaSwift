import UIKit
import XCTest
import PlasmaSwift

class Tests: XCTestCase {
    
    func testExample() {
        // This is an example of a functional test case.
        let client = PlasmaClient(host: "localhost", port: 50051)
        
        do {
            try client.subscribe(eventTypes: ["111", "222"]) { _ in
                // do something
            }
        } catch let error {
            XCTAssert(false, "Failed with error: \(error)")
        }
        
        XCTAssert(true, "Pass")
    }
}
