import XCTest
@testable import XMLRPCSerialization

class XMLRPCDecoderTests: XCTestCase {
    
    func testSimpleDecode() throws {
        let rawXML = xmlHeader + """
            <methodResponse><params>
                <param><value><string>a</string></value></param>
                <param><value><i4>5</i4></value></param>
                <param><value><struct>
                    <member><name>c</name><value><string>d</string></value></member>
                </struct></value></param>
            </params></methodResponse>
            """
        let decoder = XMLRPCDecoder()
        let obj = try decoder.decode(SimpleTest.self, from: rawXML.xmlData, autoUnwrappingStructures: false)

        XCTAssertEqual(obj.a, "a")
        XCTAssertEqual(obj.b, 5)
        XCTAssertEqual(obj.c["c"], "d")
    }
    
    func testWrappingDecode() throws {
        let rawXML = xmlHeader + """
            <methodResponse><params>
                <param><value><struct>
                    <member><name>a</name><value><string>a</string></value></member>
                    <member><name>b</name><value><string>b</string></value></member>
                    <member><name>c</name><value><struct>
                        <member><name>c</name><value><string>d</string></value></member>
                    </struct></value></member>
                </struct></value></param>
            </params></methodResponse>
            """
        let decoder = XMLRPCDecoder()
        let obj = try decoder.decode(WrappingTest.self, from: rawXML.xmlData, autoUnwrappingStructures: true)
        
        XCTAssertEqual(obj.a, "a")
        XCTAssertEqual(obj.b, "b")
        XCTAssertEqual(obj.c["c"], "d")
    }
    
    func testMethodCallDecode() throws {
        let rawXML = xmlHeader + """
            <methodCall><methodName>test.method</methodName><params>
                <param><value><struct>
                    <member><name>a</name><value><string>a</string></value></member>
                    <member><name>b</name><value><string>b</string></value></member>
                    <member><name>c</name><value><struct>
                        <member><name>c</name><value><string>d</string></value></member>
                    </struct></value></member>
                </struct></value></param>
            </params></methodCall>
            """
        let decoder = XMLRPCDecoder()
        let obj = try decoder.decode(WrappingTestRequest.self, from: rawXML.xmlData, autoUnwrappingStructures: true)

        XCTAssertEqual(obj.a, "a")
        XCTAssertEqual(obj.b, "b")
        XCTAssertEqual(obj.c["c"], "d")
    }
    
    func testTypesDecode() throws {
        let rawIntXML = """
            <?xml version=\"1.0\" encoding=\"utf-8\"?>
            <methodResponse><params><param><value><struct>
                <member><name>tiny_s</name><value><i4>-128</i4></value></member>
                <member><name>tiny_u</name><value><i4>255</i4></value></member>
                <member><name>small_s</name><value><i4>-32768</i4></value></member>
                <member><name>small_u</name><value><i4>65535</i4></value></member>
                <member><name>large_s</name><value><i4>-2147483648</i4></value></member>
                <member><name>large_u</name><value><i4>4294967295</i4></value></member>
                <member><name>huge_s</name><value><i4>-9223372036854775808</i4></value></member>
                <member><name>huge_u</name><value><i4>18446744073709551615</i4></value></member>
            </struct></value></param></params></methodResponse>
            """
        let rawFPXML = """
            <?xml version=\"1.0\" encoding=\"utf-8\"?>
            <methodResponse><params><param><value><struct>
                <member><name>small</name><value><double>2.0</double></value>
                </member><member><name>large</name><value><double>2.0</double></value></member>
            </struct></value></param></params></methodResponse>
            """
        let decoder = XMLRPCDecoder()
        let intObj = try decoder.decode(IntTypesTest.self, from: rawIntXML.xmlData), intDesired = IntTypesTest.filled()
        let fpObj = try decoder.decode(FPTypesTest.self, from: rawFPXML.xmlData), fpDesired = FPTypesTest.filled()
        
        XCTAssertEqual(intObj.tiny_s, intDesired.tiny_s)
        XCTAssertEqual(intObj.tiny_u, intDesired.tiny_u)
        XCTAssertEqual(intObj.small_s, intDesired.small_s)
        XCTAssertEqual(intObj.small_u, intDesired.small_u)
        XCTAssertEqual(intObj.large_s, intDesired.large_s)
        XCTAssertEqual(intObj.large_u, intDesired.large_u)
        XCTAssertEqual(intObj.huge_s, intDesired.huge_s)
        XCTAssertEqual(intObj.huge_u, intDesired.huge_u)
        XCTAssertEqual(fpObj.small, fpDesired.small, accuracy: 0.000000119209286)
        XCTAssertEqual(fpObj.large, fpDesired.large, accuracy: 0.000000000000000222044605)
        
        let rawFailXML = """
            <?xml version=\"1.0\" encoding=\"utf-8\"?>
            <methodResponse><params><param><value><struct>
                <member><name>tiny_s</name><value><i4>-255</i4></value></member>
                <member><name>tiny_u</name><value><i4>255</i4></value></member>
                <member><name>small_s</name><value><i4>-32768</i4></value></member>
                <member><name>small_u</name><value><i4>65535</i4></value></member>
                <member><name>large_s</name><value><i4>-2147483648</i4></value></member>
                <member><name>large_u</name><value><i4>4294967295</i4></value></member>
                <member><name>huge_s</name><value><i4>-9223372036854775808</i4></value></member>
                <member><name>huge_u</name><value><i4>18446744073709551615</i4></value></member>
            </struct></value></param></params></methodResponse>
            """
        XCTAssertThrowsError(_ = try decoder.decode(IntTypesTest.self, from: rawFailXML.xmlData)) {
            guard let error = $0 as? Swift.DecodingError else {
	            XCTFail("expected decoding error, got \($0)")
                return
            }
            guard case .dataCorrupted(let context) = error else {
                XCTFail("expected data corrupted error, got \($0)")
                return
            }
            XCTAssertEqual(context.codingPath.count, 2)
            XCTAssertEqual(context.codingPath[0].stringValue, _XMLRPCCodingKey(intValue: 0)?.stringValue)
            XCTAssertEqual(context.codingPath[1].stringValue, "tiny_s")
            XCTAssertEqual(context.debugDescription, "Int8 can't hold -255")
        }
    }
    
    func testDecodeIntAsUInt() throws {
        let rawXML = xmlHeader + """
            <methodResponse><params><param><value><i4>1</i4></value></param></params></methodResponse>
            """
        let decoder = XMLRPCDecoder()
        let value1 = try decoder.decode(Int.self, from: rawXML.xmlData)
        
        XCTAssertEqual(value1, 1)
        
        let value2 = try decoder.decode(UInt.self, from: rawXML.xmlData)
        
        XCTAssertEqual(value2, 1)
        
        let rawFailXML = xmlHeader + """
            <methodResponse><params><param><value><i4>-1</i4></value></param></params></methodResponse>
            """
        
        XCTAssertThrowsError(_ = try decoder.decode(UInt.self, from: rawFailXML.xmlData)) {
            guard let error = $0 as? Swift.DecodingError else {
                XCTFail("expected decoding error, got \($0)")
                return
            }
            guard case .dataCorrupted(let context) = error else {
                XCTFail("expected data corrupted error, got \($0)")
                return
            }
            XCTAssertEqual(context.codingPath.count, 1)
            
        }
    }

    func testAllTestsIsComplete() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let linuxCount = type(of: self).allTests.count
            let darwinCount = type(of: self).defaultTestSuite.testCaseCount
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }

    static var allTests = [
        ("testSimpleDecode", testSimpleDecode),
        ("testWrappingDecode", testWrappingDecode),
        ("testMethodCallDecode", testMethodCallDecode),
        ("testTypesDecode", testTypesDecode),
        ("testDecodeIntAsUInt", testDecodeIntAsUInt),
        ("testAllTestsIsComplete", testAllTestsIsComplete),
    ]
}

