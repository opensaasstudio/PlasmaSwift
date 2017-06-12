import UIKit
import XCTest
import PlasmaSwift

class Tests: XCTestCase {
    
    func testExample() {
        // This is an example of a functional test case.
        PlasmaClient(host: "localhost", port: 50051)
            .connect { (result, payload, error) in
                // do something
        }
        
        XCTAssert(true, "Pass")
    }
}
