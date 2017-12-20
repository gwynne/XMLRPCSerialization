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

func XCTAssertKey<T>(
    _ key: String,
    existsIn obj: [String: Any]?,
    withType desired: T.Type,
    file: StaticString = #file,
    line: UInt = #line
) -> T? {
    guard let obj = obj else { return nil }
    
    guard let value = obj[key] else {
        XCTFail("\(key) does not exist in object", file: file, line: line)
        return nil
    }
    guard let typedValue = value as? T else {
        XCTFail("Value is \(type(of: value)), expected \(T.self)", file: file, line: line)
        return nil
    }
    return typedValue
}

func XCTAssertKey<T: Equatable>(
    _ key: String,
    existsIn obj: [String: Any]?,
    havingValue expected: T,
    file: StaticString = #file,
    line: UInt = #line
) {
    guard let obj = obj else { return }
    
    guard let value = obj[key] else {
        XCTFail("\(key) does not exist in object", file: file, line: line)
        return
    }
    guard let typedValue = value as? T else {
        XCTFail("Value is \(type(of: value)), expected \(T.self)", file: file, line: line)
        return
    }
    XCTAssertEqual(typedValue, expected, file: file, line: line)
}

func XCTAssertKey<T: BinaryFloatingPoint>(
    _ key: String,
    existsIn obj: [String: Any]?,
    havingValue expected: T,
    file: StaticString = #file,
    line: UInt = #line
) {
    guard let obj = obj else { return }
    
    guard let value = obj[key] else {
        XCTFail("\(key) does not exist in object", file: file, line: line)
        return
    }
    guard let typedValue = value as? T else {
        XCTFail("Value is \(type(of: value)), expected \(T.self)", file: file, line: line)
        return
    }
    // Don't even ask how I figured out this value. It wasn't by looking it up.
    XCTAssertEqual(typedValue, expected, accuracy: 0.000000000000000222044605, file: file, line: line)
}
