import XCTest
@testable import XMLRPCSerialization

let xmlBlob = "<param><value><struct><member><name>integers</name><value><struct><member><name>tiny_s</name><value><i4>-128</i4></value></member><member><name>tiny_u</name><value><i4>255</i4></value></member><member><name>small_s</name><value><i4>-32768</i4></value></member><member><name>small_u</name><value><i4>65535</i4></value></member><member><name>large_s</name><value><i4>-2147483648</i4></value></member><member><name>large_u</name><value><i4>4294967295</i4></value></member><member><name>huge_s</name><value><i4>-9223372036854775808</i4></value></member><member><name>huge_u</name><value><i4>18446744073709551615</i4></value></member></struct></value></member><member><name>decimals</name><value><struct><member><name>small</name><value><double>2.0</double></value></member><member><name>large</name><value><double>2.0</double></value></member></struct></value></member><member><name>other</name><value><struct><member><name>data</name><value><base64>YXNkZmFzZGZhc2RmYXNkZg==</base64></value></member><member><name>date</name><value><dateTime.iso8601>0001-12-30T00:00:00Z</dateTime.iso8601></value></member><member><name>boolean</name><value><boolean>0</boolean></value></member><member><name>textual</name><value><string>I am quite a bit of complicated text ❗️</string></value></member></struct></value></member><member><name>nesting</name><value><struct><member><name>array</name><value><array><data><value><string>1</string></value><value><string>a</string></value><value><string>true</string></value></data></array></value></member><member><name>data</name><value><base64>SSBhbSBxdWl0ZSBhIGJpdCBvZiBjb21wbGljYXRlZCB0ZXh0IOKdl++4jw==</base64></value></member><member><name>textual</name><value><string>I am quite a bit of complicated text ❗️</string></value></member><member><name>deep</name><value><struct><member><name>deepArray</name><value><array><data><value><i4>0</i4></value><value><i4>5</i4></value><value><i4>9223372036854775807</i4></value></data></array></value></member><member><name>deepData</name><value><base64>ZmRmc2E=</base64></value></member><member><name>deepDate</name><value><dateTime.iso8601>4001-01-01T00:00:00Z</dateTime.iso8601></value></member><member><name>deepTextual</name><value><string>whatever</string></value></member></struct></value></member></struct></value></member></struct></value></param>"

class XMLRPCParamCoderTests: XCTestCase {
    func testDecoder() throws {
        let xml = try XMLElement(xmlString: xmlBlob)
        let obj = try XMLRPCParamDecoder().decode(from: xml)
        
        guard let topLevel = obj as? [String: Any] else { XCTFail("top level is not object"); return }
        
        let integersObj = XCTAssertKey("integers", existsIn: topLevel, withType: [String: Any].self)
        XCTAssertKey("tiny_s", existsIn: integersObj, havingValue: Int(Int8.min))
        XCTAssertKey("tiny_u", existsIn: integersObj, havingValue: UInt(UInt8.max))
        XCTAssertKey("small_s", existsIn: integersObj, havingValue: Int(Int16.min))
        XCTAssertKey("small_u", existsIn: integersObj, havingValue: UInt(UInt16.max))
        XCTAssertKey("large_s", existsIn: integersObj, havingValue: Int(Int32.min))
        XCTAssertKey("large_u", existsIn: integersObj, havingValue: UInt(UInt32.max))
        XCTAssertKey("huge_s", existsIn: integersObj, havingValue: Int(Int64.min))
        XCTAssertKey("huge_u", existsIn: integersObj, havingValue: UInt(UInt64.max))
        
        let decimalsObj = XCTAssertKey("decimals", existsIn: topLevel, withType: [String: Any].self)
        XCTAssertKey("small", existsIn: decimalsObj, havingValue: Double.greatestFiniteMagnitude.significand)
        XCTAssertKey("large", existsIn: decimalsObj, havingValue: Double.greatestFiniteMagnitude.significand)
        
        let otherObj = XCTAssertKey("other", existsIn: topLevel, withType: [String: Any].self)
        XCTAssertKey("data", existsIn: otherObj, havingValue: Data(base64Encoded: "YXNkZmFzZGZhc2RmYXNkZg==")!)
        XCTAssertKey("date", existsIn: otherObj, havingValue: sharedIso8601Formatter.date(from: "0001-12-30T00:00:00Z")!)
        XCTAssertKey("boolean", existsIn: otherObj, havingValue: false)
        XCTAssertKey("textual", existsIn: otherObj, havingValue: "I am quite a bit of complicated text ❗️")
        
        let nestingObj = XCTAssertKey("nesting", existsIn: topLevel, withType: [String: Any].self)
        let nestingArray = XCTAssertKey("array", existsIn: nestingObj, withType: [Any].self)
        XCTAssertEqual(nestingArray?.count, 3)
        XCTAssertEqual(nestingArray?[0] as? String, "1")
        XCTAssertEqual(nestingArray?[1] as? String, "a")
        XCTAssertEqual(nestingArray?[2] as? String, "true")
        XCTAssertKey("data", existsIn: nestingObj, havingValue: Data(base64Encoded: "SSBhbSBxdWl0ZSBhIGJpdCBvZiBjb21wbGljYXRlZCB0ZXh0IOKdl++4jw==")!)
        XCTAssertKey("textual", existsIn: nestingObj, havingValue: "I am quite a bit of complicated text ❗️")
        
        let deepNestingObj = XCTAssertKey("deep", existsIn: nestingObj, withType: [String: Any].self)
        let deepArray = XCTAssertKey("deepArray", existsIn: deepNestingObj, withType: [Any].self)
        XCTAssertEqual(deepArray?.count, 3)
        XCTAssertEqual(deepArray?[0] as? UInt, 0)
        XCTAssertEqual(deepArray?[1] as? UInt, 5)
        XCTAssertEqual(deepArray?[2] as? UInt, UInt(Int.max))
        XCTAssertKey("deepData", existsIn: deepNestingObj, havingValue: Data(base64Encoded: "ZmRmc2E=")!)
        XCTAssertKey("deepDate", existsIn: deepNestingObj, havingValue: sharedIso8601Formatter.date(from: "4001-01-01T00:00:00Z")!)
        XCTAssertKey("deepTextual", existsIn: deepNestingObj, havingValue: "whatever")
    }
    
    func testEncoder() throws {
        let obj: [(String, Any)] = [
            ("integers", [
                ("tiny_s", Int8.min),
                ("tiny_u", UInt8.max),
                ("small_s", Int16.min),
                ("small_u", UInt16.max),
                ("large_s", Int32.min),
                ("large_u", UInt32.max),
                ("huge_s", Int64.min),
                ("huge_u", UInt64.max),
            ]),
            ("decimals", [
                ("small", Float.greatestFiniteMagnitude.significand),
                ("large", Double.greatestFiniteMagnitude.significand),
            ]),
            ("other", [
                ("data", "asdfasdfasdfasdf".data(using: .utf8)!),
                ("date", sharedIso8601Formatter.date(from: "0001-12-29T18:09:24-05:50:36")!),
                ("boolean", false),
                ("textual", "I am quite a bit of complicated text ❗️"),
            ]),
            ("nesting", [
                ("array", ["1", "a", "true"]),
                ("data", "I am quite a bit of complicated text ❗️".data(using: .utf8)!),
                ("textual", "I am quite a bit of complicated text ❗️"),
                ("deep", [
                    ("deepArray", [0, 5, Int.max]),
                    ("deepData", "fdfsa".data(using: .isoLatin1)!),
                    ("deepDate", sharedIso8601Formatter.date(from: "4000-12-31T18:00:00-06:00")!),
                    ("deepTextual", "whatever"),
                ])
            ])
        ]
        
        let d = try XMLRPCParamEncoder().encode(obj)
        
        XCTAssertEqual(d.name, "param")
        XCTAssertEqual(d.childCount, 1)
        
        let vs = d.elements(forName: "value")
        XCTAssertEqual(vs.count, 1)
        let v = vs[0]
        XCTAssertEqual(v.name, "value")
        
        let sts = v.elements(forName: "struct")
        XCTAssertEqual(sts.count, 1)
        let st = sts[0]
        XCTAssertEqual(st.name, "struct")
        
        // TODO: The rest of the structure as elements instead of a string compare
        XCTAssertEqual(d.xmlString, xmlBlob)
//        print(d.xmlString(options: []))
    }
    
    func testEncodeEmptyArray() throws {
        let arr: [String] = []
        let encoder = XMLRPCParamEncoder()
        let element = try encoder.encode(arr)
        let readable = element.xmlString
        
        XCTAssertEqual(readable, "<param><value><array><data></data></array></value></param>")
    }

    func testAllTestsIsComplete() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let linuxCount = type(of: self).allTests.count
            let darwinCount = type(of: self).defaultTestSuite.testCaseCount
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }
    
    static var allTests = [
        ("testDecoder", testDecoder),
        ("testEncoder", testEncoder),
        ("testEncodeEmptyArray", testEncodeEmptyArray),
        ("testAllTestsIsComplete", testAllTestsIsComplete),
    ]
}

