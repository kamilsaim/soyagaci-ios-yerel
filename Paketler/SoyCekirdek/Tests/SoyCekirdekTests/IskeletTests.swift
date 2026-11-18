import XCTest
@testable import SoyCekirdek

final class IskeletTests: XCTestCase {
    func test_surum() {
        XCTAssertEqual(Surum.web, "7.0.0")
    }
}
