import UIKit
import XCTest
import PlasmaSwift

class Tests: XCTestCase {
    
    func testExample() {
        // This is an example of a functional test case.
        let client = try! PlasmaClient(host: "localhost", port: 50051)
        client.connect() { _ in
            // do something
        }
        
        XCTAssert(true, "Pass")
    }
}
