import XCTest
@testable import XMLRPCSerialization

class XMLRPCDecoderTests: XCTestCase {
    
    func testSimpleDecode() throws {
        let rawXML = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<methodResponse><params><param><value><string>a</string></value></param><param><value><string>b</string></value></param><param><value><struct><member><name>c</name><value><string>d</string></value></member></struct></value></param></params></methodResponse>".data(using: .utf8)!
        let decoder = XMLRPCDecoder()
        let obj = try decoder.decode(SimpleTest.self, from: rawXML, autoUnwrappingStructures: false)

        XCTAssertEqual(obj.a, "a")
        XCTAssertEqual(obj.b, "b")
        XCTAssertEqual(obj.c["c"], "d")
    }
    
    func testWrappingDecode() throws {
        let rawXML = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<methodResponse><params><param><value><struct><member><name>a</name><value><string>a</string></value></member><member><name>b</name><value><string>b</string></value></member><member><name>c</name><value><struct><member><name>c</name><value><string>d</string></value></member></struct></value></member></struct></value></param></params></methodResponse>".data(using: .utf8)!
        let decoder = XMLRPCDecoder()
        let obj = try decoder.decode(WrappingTest.self, from: rawXML, autoUnwrappingStructures: true)
        
        XCTAssertEqual(obj.a, "a")
        XCTAssertEqual(obj.b, "b")
        XCTAssertEqual(obj.c["c"], "d")
    }
    
    func testMethodCallDecode() throws {
        let rawXML = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<methodCall><methodName>test.method</methodName><params><param><value><struct><member><name>a</name><value><string>a</string></value></member><member><name>b</name><value><string>b</string></value></member><member><name>c</name><value><struct><member><name>c</name><value><string>d</string></value></member></struct></value></member></struct></value></param></params></methodCall>".data(using: .utf8)!
        let decoder = XMLRPCDecoder()
        let obj = try decoder.decode(WrappingTestRequest.self, from: rawXML, autoUnwrappingStructures: true)

        XCTAssertEqual(obj.a, "a")
        XCTAssertEqual(obj.b, "b")
        XCTAssertEqual(obj.c["c"], "d")
    }

    static var allTests = [
        ("testSimpleDecode", testSimpleDecode),
        ("testWrappingDecode", testWrappingDecode),
        ("testMethodCallDecode", testMethodCallDecode),
    ]
}
