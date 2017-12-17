import XCTest
@testable import XMLRPCSerialization

struct XMLRPCTest: Codable {
    struct integersTest: Codable {
        let tiny_s: Int8
        let tiny_u: UInt8
        let small_s: Int16
        let small_u: UInt16
        let large_s: Int32
        let large_u: UInt32
        let huge_s: Int64
        let huge_u: UInt64
    }
    struct decimalsTest: Codable {
        let small: Float
        let large: Double
    }
    struct otherTest: Codable {
        let data: Data
        let date: Date
        let boolean: Bool
        let textual: String
    }
    struct nestingTest: Codable {
        struct deepNestingTest: Codable {
            let deepArray: [Int]
            let deepData: Data
            let deepDate: Date
            let deepTextual: String
        }
        let array: [String]
        let data: Data
        let textual: String
        let deep: deepNestingTest
    }
    
    let integers: integersTest
    let decimals: decimalsTest
    let other: otherTest
    let nesting: nestingTest
}

class XMLRPCParamCoderTests: XCTestCase {
//    func testDecoder() throws {
//        let raw = """
//            """.data(using: .utf8)!
//
//        do {
//            //let t = try XMLRPCParamDecoder.decode(XMLRPCTest.self, from: raw)
//
//        } catch {
//            // Because what XCTest prints for decoder errors is really really useless
//            print(error)
//            throw error
//        }
//    }
    
    func testEncoder() throws {
        let obj = XMLRPCTest(
        	integers: .init(
         	    tiny_s: Int8.min,
                tiny_u: UInt8.max,
                small_s: Int16.min,
                small_u: UInt16.max,
                large_s: Int32.min,
                large_u: UInt32.max,
                huge_s: Int64.min,
                huge_u: UInt64.max
            ),
            decimals: .init(
                small: Float.greatestFiniteMagnitude.significand,
                large: Double.greatestFiniteMagnitude.significand
            ),
            other: .init(
                data: "asdfasdfasdfasdf".data(using: .utf8)!,
                date: Date.distantPast,
                boolean: false,
                textual: "I am quite a bit of complicated text ❗️"
            ),
            nesting: .init(
                array: ["1", "a", "true"],
                data: "I am quite a bit of complicated text ❗️".data(using: .utf8)!,
                textual: "I am quite a bit of complicated text ❗️",
                deep: .init(
                    deepArray: [0, 5, Int.max],
                    deepData: "fdfsa".data(using: .isoLatin1)!,
                    deepDate: Date.distantFuture,
                    deepTextual: "whatever"
                )
            )
        )
        
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
#if os(Linux)
        let xml = "<param><value><struct><member><name>integers</name><value><struct><member><name>tiny_s</name><value><int>-128</int></value></member><member><name>tiny_u</name><value><int>255</int></value></member><member><name>small_s</name><value><int>-32768</int></value></member><member><name>small_u</name><value><int>65535</int></value></member><member><name>large_s</name><value><int>-2147483648</int></value></member><member><name>large_u</name><value><int>4294967295</int></value></member><member><name>huge_s</name><value><int>-9223372036854775808</int></value></member><member><name>huge_u</name><value><int>18446744073709551615</int></value></member></struct></value></member><member><name>decimals</name><value><struct><member><name>small</name><value><double>2.0</double></value></member><member><name>large</name><value><double>2.0</double></value></member></struct></value></member><member><name>other</name><value><struct><member><name>data</name><value><base64>YXNkZmFzZGZhc2RmYXNkZg==</base64></value></member><member><name>date</name><value><dateTime.iso8601>0001-12-30T00:00:00Z</dateTime.iso8601></value></member><member><name>boolean</name><value><boolean>0</boolean></value></member><member><name>textual</name><value><string>I am quite a bit of complicated text ❗️</string></value></member></struct></value></member><member><name>nesting</name><value><struct><member><name>array</name><value><array><data><value><string>1</string></value><value><string>a</string></value><value><string>true</string></value></data></array></value></member><member><name>data</name><value><base64>SSBhbSBxdWl0ZSBhIGJpdCBvZiBjb21wbGljYXRlZCB0ZXh0IOKdl++4jw==</base64></value></member><member><name>textual</name><value><string>I am quite a bit of complicated text ❗️</string></value></member><member><name>deep</name><value><struct><member><name>deepArray</name><value><array><data><value><int>0</int></value><value><int>5</int></value><value><int>9223372036854775807</int></value></data></array></value></member><member><name>deepData</name><value><base64>ZmRmc2E=</base64></value></member><member><name>deepDate</name><value><dateTime.iso8601>4001-01-01T00:00:00Z</dateTime.iso8601></value></member><member><name>deepTextual</name><value><string>whatever</string></value></member></struct></value></member></struct></value></member></struct></value></param>"
#else
        let xml = "<param><value><struct><member><name>integers</name><value><struct><member><name>tiny_s</name><value><int>-128</int></value></member><member><name>tiny_u</name><value><int>255</int></value></member><member><name>small_s</name><value><int>-32768</int></value></member><member><name>small_u</name><value><int>65535</int></value></member><member><name>large_s</name><value><int>-2147483648</int></value></member><member><name>large_u</name><value><int>4294967295</int></value></member><member><name>huge_s</name><value><int>-9223372036854775808</int></value></member><member><name>huge_u</name><value><int>18446744073709551615</int></value></member></struct></value></member><member><name>decimals</name><value><struct><member><name>small</name><value><double>2.0</double></value></member><member><name>large</name><value><double>2.0</double></value></member></struct></value></member><member><name>other</name><value><struct><member><name>data</name><value><base64>YXNkZmFzZGZhc2RmYXNkZg==</base64></value></member><member><name>date</name><value><dateTime.iso8601>0001-12-29T18:09:24-05:50:36</dateTime.iso8601></value></member><member><name>boolean</name><value><boolean>0</boolean></value></member><member><name>textual</name><value><string>I am quite a bit of complicated text ❗️</string></value></member></struct></value></member><member><name>nesting</name><value><struct><member><name>array</name><value><array><data><value><string>1</string></value><value><string>a</string></value><value><string>true</string></value></data></array></value></member><member><name>data</name><value><base64>SSBhbSBxdWl0ZSBhIGJpdCBvZiBjb21wbGljYXRlZCB0ZXh0IOKdl++4jw==</base64></value></member><member><name>textual</name><value><string>I am quite a bit of complicated text ❗️</string></value></member><member><name>deep</name><value><struct><member><name>deepArray</name><value><array><data><value><int>0</int></value><value><int>5</int></value><value><int>9223372036854775807</int></value></data></array></value></member><member><name>deepData</name><value><base64>ZmRmc2E=</base64></value></member><member><name>deepDate</name><value><dateTime.iso8601>4000-12-31T18:00:00-06:00</dateTime.iso8601></value></member><member><name>deepTextual</name><value><string>whatever</string></value></member></struct></value></member></struct></value></member></struct></value></param>"
#endif
        XCTAssertEqual(d.xmlString, xml)
//        print(d.xmlString(options: []))
    }

    static var allTests = [
//        ("testDecoder", testDecoder),
        ("testEncoder", testEncoder),
    ]
}

