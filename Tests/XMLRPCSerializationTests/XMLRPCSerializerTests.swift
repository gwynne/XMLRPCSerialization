import XCTest
@testable import XMLRPCSerialization

class XMLRPCSerializerTests: XCTestCase {
    
    func testXmlrpcRequest() throws {
        let rawXML = "<methodCall><methodName>test.method</methodName><params><param><value><int>1</int></value></param><param><value><string>a</string></value></param><param><value><boolean>0</boolean></value></param></params></methodCall>"
        
        let obj = try XMLRPCSerialization.xmlrpcRequest(from: rawXML.data(using: .utf8)!, options: [])
        
        XCTAssertEqual(obj.methodName, "test.method")
        XCTAssertEqual(obj.params.count, 3)
        XCTAssertEqual(obj.params[0] as? UInt, 1)
        XCTAssertEqual(obj.params[1] as? String, "a")
        XCTAssertEqual(obj.params[2] as? Bool, false)
    }

    func testXmlrpcResponseNormal() throws {
        let rawXML = "<methodResponse><params><param><value><struct><member><name>_messages</name><value><array><data><value><string>test.success</string></value></data></array></value></member><member><name>_success</name><value><i4>1</i4></value></member></struct></value></param></params></methodResponse>"
        
        let obj = try XMLRPCSerialization.xmlrpcResponse(from: rawXML.data(using: .utf8)!, options: [])
        
        switch obj {
            case .response(let params):
                XCTAssertEqual(params.count, 1)
                XCTAssert(params[0] is [String: Any])
                
                let obj1 = params[0] as? [String: Any]
                XCTAssert(obj1?["_messages"] is [Any])
                let arr1 = obj1?["_messages"] as? [Any]
                XCTAssertEqual(arr1?.count, 1)
                XCTAssertEqual(arr1?[0] as? String, "test.success")
                XCTAssertEqual(obj1?["_success"] as? UInt, 1)
            default:
                XCTFail("response object is not normal response")
        }
    }
    
    func testXmlrpcResponseFault() throws {
        let rawXML = "<methodResponse><fault><value><struct><member><name>faultCode</name><value><i4>1</i4></value></member><member><name>faultString</name><value><string>fault</string></value></member></struct></value></fault></methodResponse>"
        
        let obj = try XMLRPCSerialization.xmlrpcResponse(from: rawXML.data(using: .utf8)!, options: [])
        
        switch obj {
            case .fault(let code, let string):
                XCTAssertEqual(code, 1)
                XCTAssertEqual(string, "fault")
            default:
                XCTFail("response object is not fault")
        }
    }
    
    func testDataRequest() throws {
        let obj = try XMLRPCSerialization.string(
        	withXmlrpcRequest: XMLRPCRequest(methodName: "test.method", params: [
                1,
                "a",
                false
            ]),
            options: [])
        let rawXML = "<methodCall><methodName>test.method</methodName><params><param><value><i4>1</i4></value></param><param><value><string>a</string></value></param><param><value><boolean>0</boolean></value></param></params></methodCall>"
        
        XCTAssertEqual(obj, rawXML, "returned the right data")
    }

    func testDataResponseNormal() throws {
        do {
            let nested: [(String, Any)] = [
                ("_messages", ["test.success"]),
                ("_success", 1)
            ]
            let array: [Any] = [nested]
            let obj = try XMLRPCSerialization.string(
                withXmlrpcResponse: XMLRPCResponse.response(array),
                options: [])
            let rawXML = "<methodResponse><params><param><value><struct><member><name>_messages</name><value><array><data><value><string>test.success</string></value></data></array></value></member><member><name>_success</name><value><i4>1</i4></value></member></struct></value></param></params></methodResponse>"

            XCTAssertEqual(obj, rawXML, "returned the right data")
        } catch {
            print(error)
            throw error
        }
    }

    func testDataResponseFault() throws {
        do {
            let obj = try XMLRPCSerialization.string(
                withXmlrpcResponse: XMLRPCResponse.fault(code: 1, string: "fault"),
                options: [])
            let rawXML = "<methodResponse><fault><value><struct><member><name>faultCode</name><value><i4>1</i4></value></member><member><name>faultString</name><value><string>fault</string></value></member></struct></value></fault></methodResponse>"

            XCTAssertEqual(obj, rawXML, "returned the right data")
        } catch {
            print(error)
            throw error
        }
    }

    static var allTests = [
        ("testXmlrpcRequest", testXmlrpcRequest),
        ("testXmlrpcResponseNormal", testXmlrpcResponseNormal),
        ("testXmlrpcResponseFault", testXmlrpcResponseFault),
        ("testDataRequest", testDataRequest),
        ("testDataResponseNormal", testDataResponseNormal),
        ("testDataResponseFault", testDataResponseFault),
    ]
}
