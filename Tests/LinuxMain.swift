import XCTest
@testable import XMLRPCSerializationTests

XCTMain([
    testCase(XMLRPCSerializerTests.allTests),
    testCase(XMLRPCParamCoderTests.allTests),
])
