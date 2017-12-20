import XCTest
@testable import XMLRPCSerialization

struct SimpleTest: Codable, XMLRPCResponseEncodable {
    let a: String
    let b: String
    let c: [String: String]
    
    init() {
        self.a = "a"
        self.b = "b"
        self.c = ["c": "d"]
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.a = try container.decode(String.self)
        self.b = try container.decode(String.self)
        self.c = try container.decode(Dictionary<String, String>.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(a)
        try container.encode(b)
        try container.encode(c)
    }
}

struct WrappingTest: Codable, XMLRPCResponseEncodable {
    let a: String
    let b: String
    let c: [String: String]
    
    init() {
        self.a = "a"
        self.b = "b"
        self.c = ["c": "d"]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: WrappingTest.CodingKeys.self)

        try container.encode(a, forKey: .a)
        try container.encode(b, forKey: .b)
        try container.encode(c, forKey: .c)
    }
}

struct WrappingTestRequest: Codable, XMLRPCRequestEncodable {
    func xmlrpcMethodName() -> String {
        return "test.method"
    }
    
    let a: String
    let b: String
    let c: [String: String]
    
    init() {
        self.a = "a"
        self.b = "b"
        self.c = ["c": "d"]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: WrappingTestRequest.CodingKeys.self)

        try container.encode(a, forKey: .a)
        try container.encode(b, forKey: .b)
        try container.encode(c, forKey: .c)
    }
}

class XMLRPCEncoderTests: XCTestCase {
    
    func testSimpleEncode() throws {
        let encoder = XMLRPCEncoder()
        let obj = SimpleTest()
        
        let data = try encoder.encode(obj, autoWrappingStructures: false)
        
        XCTAssertEqual(data, "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<methodResponse><params><param><value><string>a</string></value></param><param><value><string>b</string></value></param><param><value><struct><member><name>c</name><value><string>d</string></value></member></struct></value></param></params></methodResponse>".data(using: .utf8)!)
    }
    
    func testWrappingEncode() throws {
        let encoder = XMLRPCEncoder()
        let obj = WrappingTest()
        let data = try encoder.encode(obj, autoWrappingStructures: true)
        
        let outPrefix = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<methodResponse><params><param><value><struct>"
        let possibleOrderings = [[0,1,2], [0,2,1], [1,0,2], [1,2,0], [2,0,1], [2,1,0]]
        let items = [
            "<member><name>a</name><value><string>a</string></value></member>",
            "<member><name>b</name><value><string>b</string></value></member>",
            "<member><name>c</name><value><struct><member><name>c</name><value><string>d</string></value></member></struct></value></member>",
        ]
        let outSuffix = "</struct></value></param></params></methodResponse>"
        let possibleOutputs = possibleOrderings.map { (o: [Int]) in outPrefix + items[o[0]] + items[o[1]] + items[o[2]] + outSuffix }
        
        XCTAssertNotNil(possibleOutputs.index { $0.data(using: .utf8)! == data }, "One of the inputs should match")
    }
    
    func testMethodCallEncode() throws {
        let encoder = XMLRPCEncoder()
        let obj = WrappingTestRequest()
        let data = try encoder.encode(obj, autoWrappingStructures: true)
        
        let outPrefix = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<methodCall><methodName>test.method</methodName><params><param><value><struct>"
        let possibleOrderings = [[0,1,2], [0,2,1], [1,0,2], [1,2,0], [2,0,1], [2,1,0]]
        let items = [
            "<member><name>a</name><value><string>a</string></value></member>",
            "<member><name>b</name><value><string>b</string></value></member>",
            "<member><name>c</name><value><struct><member><name>c</name><value><string>d</string></value></member></struct></value></member>",
        ]
        let outSuffix = "</struct></value></param></params></methodCall>"
        let possibleOutputs = possibleOrderings.map { (o: [Int]) in outPrefix + items[o[0]] + items[o[1]] + items[o[2]] + outSuffix }
        
        XCTAssertNotNil(possibleOutputs.index { $0.data(using: .utf8)! == data }, "One of the inputs should match")
    }

    static var allTests = [
        ("testSimpleEncode", testSimpleEncode),
        ("testWrappingEncode", testWrappingEncode),
        ("testMethodCallEncode", testMethodCallEncode),
    ]
}
