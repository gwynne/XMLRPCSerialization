//
//  XMLRPCCodable.swift
//  XMLRPCSerialization
//
//  Created by Gwynne Raskind on 12/19/17.
//

import Foundation

public protocol XMLRPCRequestEncodable: Encodable {
    static var xmlrpcMethodName: String { get }
}

public protocol XMLRPCRequestDecodable: Decodable {
    init(forMethodName methodName: String, from decoder: Decoder) throws
}

public protocol XMLRPCResponseEncodable: Encodable {
}

public protocol XMLRPCResponseDecodable: Decodable {
}

public typealias XMLRPCRequestCodable = XMLRPCRequestEncodable & XMLRPCRequestDecodable
public typealias XMLRPCResponseCodable = XMLRPCResponseEncodable & XMLRPCResponseDecodable

public struct XMLRPCFault: Error {
    public let faultCode: Int32
    public let faultString: String
    
    public init(faultCode: Int32, faultString: String) {
        self.faultCode = faultCode
        self.faultString = faultString
    }
}

// - MARK: Internals

struct _XMLRPCCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
}
