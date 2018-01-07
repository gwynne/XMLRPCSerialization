//
//  XMLRPCEncoder.swift
//  XMLRPCSerialization
//
//  Created by Gwynne Raskind on 12/17/17.
//

import Foundation

open class XMLRPCEncoder {
    
    open var userInfo: [CodingUserInfoKey: Any] = [:]
    
    public init() {}
    
    open func encode<T: XMLRPCRequestEncodable>(_ value: T, autoWrappingStructures: Bool = true) throws -> Data {
        let encoder = _XMLRPCEncoder(userInfo: userInfo, autoWrap: autoWrappingStructures)
        
        try value.encode(to: encoder)
        return try XMLRPCSerialization.data(withXmlrpcRequest: XMLRPCRequest(methodName: T.xmlrpcMethodName, params: encoder.storage.storage as! [Any]))
    }
    
    open func encode<T: XMLRPCResponseEncodable>(_ value: T, autoWrappingStructures: Bool = true) throws -> Data {
        let encoder = _XMLRPCEncoder(userInfo: userInfo, autoWrap: autoWrappingStructures)
        
        try value.encode(to: encoder)
        return try XMLRPCSerialization.data(withXmlrpcResponse: XMLRPCResponse.response(encoder.storage.storage as! [Any]))
    }
    
    open func encode(_ value: XMLRPCFault) throws -> Data {
        return try XMLRPCSerialization.data(withXmlrpcResponse: XMLRPCResponse.fault(code: value.faultCode, string: value.faultString))
    }
}

/// Reference container for encoding values. Compensates (badly) for `Array` and
/// `Dictionary` being value types.
class _XMLRPCValueEncodingStorage {
    var storage: Any = Array<Any>()
    
    init() {}
    
    private func _set(_ value: Any, in container: inout Any, forKey key: CodingKey) throws {
        if var arrayContainer = container as? [Any] {
            guard let index = key.intValue else {
                throw EncodingError.invalidValue(value, .init(codingPath: [key], debugDescription: "Need an int key for array container"))
            }
            switch index {
                case 0..<arrayContainer.count:
                    arrayContainer[index] = value
                case arrayContainer.count:
                    arrayContainer.append(value)
                default:
                    throw EncodingError.invalidValue(value, .init(codingPath: [key], debugDescription: "Index key \(index) is out of bounds"))
            }
            container = arrayContainer
        } else if var objectContainer = container as? [String: Any] {
            objectContainer[key.stringValue] = value
            container = objectContainer
        } else {
            throw EncodingError.invalidValue(value, .init(codingPath: [key], debugDescription: "Can't keypath into a non-container"))
        }
    }
    
    private func _set(_ value: Any, in container: inout Any, atPath path: [CodingKey]) throws {
        switch path.count {
            case 0:
                container = value
            case 1:
                try _set(value, in: &container, forKey: path[0])
            case 2...:
                if var arrayContainer = container as? [Any] {
                    guard let index = path[0].intValue else {
                        throw EncodingError.invalidValue(value, .init(codingPath: path, debugDescription: "Need an int key for array container"))
                    }
                    guard index < arrayContainer.count else {
                        throw EncodingError.invalidValue(value, .init(codingPath: path, debugDescription: "Index key \(index) is out of bounds"))
                    }
                    var contained = arrayContainer[index]
                    try _set(value, in: &contained, atPath: Array(path[1...]))
                    arrayContainer[index] = contained
                    container = arrayContainer // so much copying...
                } else if var objectContainer = container as? [String: Any] {
                    guard var contained = objectContainer[path[0].stringValue] else {
                        throw EncodingError.invalidValue(value, .init(codingPath: path, debugDescription: "String key is missing"))
                    }
                    try _set(value, in: &contained, atPath: Array(path[1...]))
                    objectContainer[path[0].stringValue] = contained
                    container = objectContainer // so much copying...
                } else {
                    throw EncodingError.invalidValue(value, .init(codingPath: path, debugDescription: "Can't keypath into a non-container"))
                }
            default:
                throw EncodingError.invalidValue(value, .init(codingPath: path, debugDescription: "can't set an XML-RPC value at top-level"))
        }
    }
    
    func set(_ value: Any, atPath path: [CodingKey]) throws {
        try _set(value, in: &storage, atPath: path)
    }
}

final class _XMLRPCEncoder: Encoder {
    
    let autoWrap: Bool
    var storage: _XMLRPCValueEncodingStorage
    
    init(userInfo: [CodingUserInfoKey: Any], codingPath: [CodingKey] = [], autoWrap: Bool, storage: _XMLRPCValueEncodingStorage = .init()) {
        self.userInfo = userInfo
        self.codingPath = codingPath
        self.autoWrap = autoWrap
        self.storage = storage
    }
    
    public var userInfo: [CodingUserInfoKey : Any]
    public var codingPath: [CodingKey]
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        guard codingPath.count > 0 || autoWrap else {
            fatalError("can't encode a dictionary at XML-RPC top level")
        }
        
        if codingPath.count == 0 {
            var outerContainer = unkeyedContainer()
            return outerContainer.nestedContainer(keyedBy: Key.self)
        } else {
            try! storage.set(Dictionary<String, Any>(), atPath: codingPath)
            return .init(_XMLRPCKeyedEncodingContainer(referencing: self, codingPath: codingPath))
        }
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        try! storage.set(Array<Any>(), atPath: codingPath)
        return _XMLRPCUnkeyedEncodingContainer(referencing: self, codingPath: codingPath)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        guard codingPath.count > 0 || autoWrap else {
            fatalError("can't encode a dictionary at XML-RPC top level")
        }
        
        if codingPath.count == 0 {
            try! storage.set(Array<Any>(), atPath: codingPath)
            return _XMLRPCUnkeyedEncodingContainer(referencing: self, codingPath: codingPath)
        } else {
            return _XMLRPCSingleValueEncodingContainer(referencing: self, codingPath: codingPath)
        }
    }
}

final class _XMLRPCKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K
    
    let encoder: _XMLRPCEncoder
    
    init(referencing: _XMLRPCEncoder, codingPath: [CodingKey]) {
        self.encoder = referencing
        self.codingPath = codingPath
    }
    
    public var codingPath: [CodingKey]

    func encodeNil(forKey key: K) throws {
        throw EncodingError.invalidValue(NSNull(), .init(codingPath: codingPath, debugDescription: "XML-RPC does not support nil"))
    }
    
    func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
        let subencoder = _XMLRPCEncoder(userInfo: encoder.userInfo, codingPath: codingPath + [key], autoWrap: encoder.autoWrap, storage: encoder.storage)
        try value.encode(to: subencoder)
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        try! encoder.storage.set(Dictionary<String, Any>(), atPath: codingPath + [key])
        return .init(_XMLRPCKeyedEncodingContainer<NestedKey>(referencing: encoder, codingPath: codingPath + [key]))
    }
    
    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        try! encoder.storage.set(Array<Any>(), atPath: codingPath + [key])
        return _XMLRPCUnkeyedEncodingContainer(referencing: encoder, codingPath: codingPath + [key])
    }
    
    func superEncoder() -> Encoder {
        return _XMLRPCEncoder(userInfo: encoder.userInfo, codingPath: codingPath, autoWrap: encoder.autoWrap, storage: encoder.storage)
    }
    
    func superEncoder(forKey key: K) -> Encoder {
        return _XMLRPCEncoder(userInfo: encoder.userInfo, codingPath: codingPath + [key], autoWrap: encoder.autoWrap, storage: encoder.storage)
    }
    
}

final class _XMLRPCUnkeyedEncodingContainer: UnkeyedEncodingContainer, SingleValueEncodingContainer {

    let encoder: _XMLRPCEncoder
    
    var nextKey: CodingKey { return _XMLRPCCodingKey(intValue: self.count)! }
    
    init(referencing: _XMLRPCEncoder, codingPath: [CodingKey]) {
        self.encoder = referencing
        self.codingPath = codingPath
    }
    
    public var count: Int = 0
    public var codingPath: [CodingKey]

    func encodeNil() throws {
        throw EncodingError.invalidValue(NSNull(), .init(codingPath: codingPath, debugDescription: "XML-RPC does not support nil"))
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        defer { self.count += 1 }
        let subencoder = _XMLRPCEncoder(userInfo: encoder.userInfo, codingPath: codingPath + [nextKey], autoWrap: encoder.autoWrap, storage: encoder.storage)
        try value.encode(to: subencoder)
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        defer { self.count += 1 }
        try! encoder.storage.set(Dictionary<String, Any>(), atPath: codingPath + [nextKey])
        return .init(_XMLRPCKeyedEncodingContainer<NestedKey>(referencing: encoder, codingPath: codingPath + [nextKey]))
    }
    
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        defer { self.count += 1 }
        try! encoder.storage.set(Array<Any>(), atPath: codingPath + [nextKey])
        return _XMLRPCUnkeyedEncodingContainer(referencing: encoder, codingPath: codingPath + [nextKey])
    }
    
    func superEncoder() -> Encoder {
        return encoder
    }
}

final class _XMLRPCSingleValueEncodingContainer: SingleValueEncodingContainer {

    let encoder: _XMLRPCEncoder
    
    init(referencing: _XMLRPCEncoder, codingPath: [CodingKey]) {
        self.encoder = referencing
        self.codingPath = codingPath
    }
    
    public var codingPath: [CodingKey]

    func encodeNil() throws {
        throw EncodingError.invalidValue(NSNull(), .init(codingPath: codingPath, debugDescription: "XML-RPC does not support nil"))
    }
    
    func encode(_ value: Bool) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: Int) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: Int8) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: Int16) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: Int32) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: Int64) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: UInt) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: UInt8) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: UInt16) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: UInt32) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: UInt64) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: Float) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: Double) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode(_ value: String) throws { try encoder.storage.set(value, atPath: codingPath) }
    func encode<T>(_ value: T) throws where T : Encodable {
        let subencoder = _XMLRPCEncoder(userInfo: encoder.userInfo, codingPath: codingPath, autoWrap: encoder.autoWrap, storage: encoder.storage)
        try value.encode(to: subencoder)
    }
}
