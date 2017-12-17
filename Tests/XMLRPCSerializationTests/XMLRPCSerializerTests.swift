import XCTest
@testable import XMLRPCSerialization

class XMLRPCSerializerTests: XCTestCase {

    func testData() throws {
        let obj = try XMLRPCSerialization.data(
        	withXmlrpcObject: XMLRPCRequest(methodName: "test.method", params: [
                1,
                "a",
                false
            ]),
            encoding: .isoLatin1,
            options: [])
        let rawXML = "<methodCall><methodName>test.method</methodName><params><param><value><int>1</int></value></param><param><value><string>a</string></value></param><param><value><boolean>0</boolean></value></param></params></methodCall>"
        
        XCTAssertEqual(obj, rawXML.data(using: .isoLatin1), "returned the right data")
    }
    
    static var allTests = [
        ("testData", testData),
    ]
}
