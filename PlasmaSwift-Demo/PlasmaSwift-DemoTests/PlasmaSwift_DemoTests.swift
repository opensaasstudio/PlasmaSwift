import UIKit
import XCTest
import PlasmaSwift

final class Tests: XCTestCase {
    func testExample() {
        PlasmaClient(host: "localhost", port: 50051).connect { (result, payload, error) in
            // do something
        }
        XCTAssert(true, "Pass")
    }
}
