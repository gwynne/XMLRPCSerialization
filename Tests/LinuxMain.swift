import XCTest
@testable import XMLRPCSerializationTests

XCTMain([
    testCase(XMLRPCSerializerTests.allTests),
    testCase(XMLRPCParamCoderTests.allTests),
    testCase(XMLRPCEncoderTests.allTests),
])
