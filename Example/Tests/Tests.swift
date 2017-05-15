import UIKit
import XCTest
import PlasmaSwift

class Tests: XCTestCase {
    
    func testExample() {
        // This is an example of a functional test case.
        let client = PlasmaClient(host: "localhost", port: 50051)
        client.subscribe(eventTypes: ["111", "222"])
        
        XCTAssert(true, "Pass")
    }
    

    
}
