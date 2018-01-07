//
//  XMLRPCDecoder.swift
//  XMLRPCSerialization
//
//  Created by Gwynne Raskind on 12/19/17.
//

import Foundation

open class XMLRPCDecoder {
    
    open var userInfo: [CodingUserInfoKey: Any] = [:]
    
    public init() {}
    
    open func decode<T: XMLRPCResponseDecodable>(_ type: T.Type, from data: Data, autoUnwrappingStructures: Bool = true) throws -> T {
        let value = try XMLRPCSerialization.xmlrpcResponse(from: data)
        switch value {
            case .response(let raw):
                let decoder = _XMLRPCDecoder(userInfo: userInfo, autoUnwrap: autoUnwrappingStructures, storage: _XMLRPCDecodingStorage(raw))
        
                return try T(from: decoder)
            case .fault(let code, let string):
                throw XMLRPCFault(faultCode: code, faultString: string)
        }
    }
    
    open func decode<T: XMLRPCRequestDecodable>(_ type: T.Type, from data: Data, autoUnwrappingStructures: Bool = true) throws -> T {
        let value = try XMLRPCSerialization.xmlrpcRequest(from: data)
        let decoder = _XMLRPCDecoder(userInfo: userInfo, autoUnwrap: autoUnwrappingStructures, storage: _XMLRPCDecodingStorage(value.params))
        
        return try T(forMethodName: value.methodName, from: decoder)
    }
}

final class _XMLRPCDecodingStorage {
    enum Storage {
        case array([Any])
        case object([String: Any])
        case value(Any)
    }
    let data: Storage
    
    var isArray: Bool { if case .array = data { return true } else { return false } }
    var isObject: Bool { if case .object = data { return true } else { return false } }
    
    init(_ data: Any) {
        if let array = data as? [Any] {
            self.data = .array(array)
        } else if let object = data as? [String: Any] {
            self.data = .object(object)
        } else {
            self.data = .value(data)
        }
    }
    
    func assertIsArray(context: [CodingKey]) throws -> [Any] {
        switch data {
            case .array(let value):
                return value
            default:
                throw DecodingError.typeMismatch(Array<Any>.self, .init(codingPath: context, debugDescription: "Needed array"))
        }
    }
    
    func assertIsObject(context: [CodingKey]) throws -> [String: Any] {
        switch data {
            case .object(let value):
                return value
            default:
                throw DecodingError.typeMismatch(Dictionary<String, Any>.self, .init(codingPath: context, debugDescription: "Needed object"))
        }
    }
    
    func assertIsIntType<T: BinaryInteger>(_ type: T.Type, context: [CodingKey]) throws -> T {
        switch data {
            case .value(let value):
                let intValue: T?
                if let value = value as? Int {
                    intValue = T.init(exactly: value)
                } else if let value = value as? UInt {
                    intValue = T.init(exactly: value)
                } else {
                    throw DecodingError.typeMismatch(T.self, .init(codingPath: context, debugDescription: "Needed integer for \(T.self)"))
                }
                guard let result = intValue else {
                    throw DecodingError.dataCorrupted(.init(codingPath: context, debugDescription: "\(T.self) can't hold \(value)"))
                }
                return result
            default:
                throw DecodingError.typeMismatch(T.self, .init(codingPath: context, debugDescription: "Needed \(T.self)"))
        }
    }

    func assertIsFloatingPointType(context: [CodingKey]) throws -> Float {
        let floatValue = try assertIsType(Double.self, context: context)
        guard let trueValue = Float.init(exactly: floatValue) else {
            throw DecodingError.dataCorrupted(.init(codingPath: context, debugDescription: "\(Float.self) can't hold \(floatValue)"))
        }
        return trueValue
    }

    func assertIsType<T>(_ type: T.Type, context: [CodingKey]) throws -> T {
        switch data {
            case .value(let value):
                guard let value = value as? T else {
                    throw DecodingError.typeMismatch(T.self, .init(codingPath: context, debugDescription: "Needed \(T.self)"))
                }
                return value
            default:
                throw DecodingError.typeMismatch(T.self, .init(codingPath: context, debugDescription: "Needed \(T.self)"))
        }
    }

    func item(forKey key: CodingKey, context: [CodingKey]) throws -> _XMLRPCDecodingStorage {
        if let index = key.intValue {
            let array = try assertIsArray(context: context)
            guard index < array.count else {
                throw DecodingError.valueNotFound(Array<Any>.self, .init(codingPath: context, debugDescription: "no value at \(index)"))
            }
            return _XMLRPCDecodingStorage(array[index])
        } else {
            let object = try assertIsObject(context: context)
            guard let value = object[key.stringValue] else {
                throw DecodingError.valueNotFound(Array<Any>.self, .init(
                    codingPath: context,
                    debugDescription: "no value for key \(key.stringValue)"
                ))
            }
            return _XMLRPCDecodingStorage(value)
        }
    }
    
    func array(forKey key: CodingKey, context: [CodingKey]) throws -> _XMLRPCDecodingStorage {
        let value = try item(forKey: key, context: context)
        guard value.isArray else {
            throw DecodingError.typeMismatch(Array<Any>.self, .init(codingPath: context, debugDescription: "Needed array for key"))
        }
        return value
    }
    
    func object(forKey key: CodingKey, context: [CodingKey]) throws -> _XMLRPCDecodingStorage {
        let value = try item(forKey: key, context: context)
        guard value.isObject else {
            throw DecodingError.typeMismatch(Dictionary<String, Any>.self, .init(codingPath: context, debugDescription: "Needed object for key"))
        }
        return value
    }
}

final class _XMLRPCDecoder: Decoder {
    
    let autoUnwrap: Bool
    var storage: _XMLRPCDecodingStorage
    
    init(userInfo: [CodingUserInfoKey: Any], codingPath: [CodingKey] = [], autoUnwrap: Bool, storage: _XMLRPCDecodingStorage) {
        self.userInfo = userInfo
        self.codingPath = codingPath
        self.autoUnwrap = autoUnwrap
        self.storage = storage
    }
    
    public var userInfo: [CodingUserInfoKey : Any]
    public var codingPath: [CodingKey]

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        guard codingPath.count > 0 || autoUnwrap else {
            throw DecodingError.typeMismatch(Dictionary<String, Any>.self, .init(
                codingPath: codingPath,
                debugDescription: "can't decode a dictionary at XML-RPC top level"
            ))
        }
        
        if codingPath.count == 0 {
            var outerContainer = try unkeyedContainer()
            return try outerContainer.nestedContainer(keyedBy: Key.self)
        } else {
            guard storage.isObject else {
                throw DecodingError.typeMismatch(Dictionary<String, Any>.self, .init(
                    codingPath: codingPath,
                    debugDescription: "requesting object where there isn't one"
                ))
            }
            return .init(_XMLRPCKeyedDecodingContainer(referencing: self, codingPath: codingPath))
        }
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard storage.isArray else {
            throw DecodingError.typeMismatch(Array<Any>.self, .init(
                codingPath: codingPath,
                debugDescription: "requesting array where there isn't one"
            ))
        }
        return try _XMLRPCUnkeyedDecodingContainer(referencing: self, codingPath: codingPath)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        guard codingPath.count > 0 || autoUnwrap else {
            throw DecodingError.typeMismatch(Any.self, .init(
                codingPath: codingPath,
                debugDescription: "can't decode a singular value at XML-RPC top level"
            ))
        }
        
        if codingPath.count == 0 {
            return try _XMLRPCUnkeyedDecodingContainer(referencing: self, codingPath: codingPath)
        } else {
            return _XMLRPCSingleValueDecodingContainer(referencing: self, codingPath: codingPath)
        }
    }
}

final class _XMLRPCKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    
    typealias Key = K
    
    let decoder: _XMLRPCDecoder
    
    init(referencing: _XMLRPCDecoder, codingPath: [CodingKey]) {
        self.decoder = referencing
        self.codingPath = codingPath
    }
    
    public var codingPath: [CodingKey]
    
    private func subdecoder(codingPath: [CodingKey], storage: _XMLRPCDecodingStorage) -> _XMLRPCDecoder {
        return _XMLRPCDecoder(
            userInfo: decoder.userInfo,
            codingPath: codingPath,
            autoUnwrap: decoder.autoUnwrap,
            storage: storage
        )
    }
    
    var allKeys: [K] { return try! decoder.storage.assertIsObject(context: codingPath).keys.flatMap{ Key(stringValue: $0) } }
    
    func contains(_ key: K) -> Bool {
        return try! decoder.storage.assertIsObject(context: codingPath)[key.stringValue] != nil
    }

    func decodeNil(forKey key: K) throws -> Bool {
        throw DecodingError.typeMismatch(NSNull.self, .init(codingPath: codingPath, debugDescription: "XML-RPC does not support nil"))
    }
    
    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T: Decodable {
        let sub = subdecoder(codingPath: codingPath + [key], storage: try decoder.storage.item(forKey: key, context: codingPath + [key]))
        
        return try T(from: sub)
    }
    
    func decodeIfPresent(_ type: Int.Type, forKey key: K) throws -> Int? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Int8.Type, forKey key: K) throws -> Int8? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Int16.Type, forKey key: K) throws -> Int16? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Int32.Type, forKey key: K) throws -> Int32? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Int64.Type, forKey key: K) throws -> Int64? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: UInt.Type, forKey key: K) throws -> UInt? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: UInt8.Type, forKey key: K) throws -> UInt8? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: UInt16.Type, forKey key: K) throws -> UInt16? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: UInt32.Type, forKey key: K) throws -> UInt32? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: UInt64.Type, forKey key: K) throws -> UInt64? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Float.Type, forKey key: K) throws -> Float? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Double.Type, forKey key: K) throws -> Double? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: Bool.Type, forKey key: K) throws -> Bool? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent(_ type: String.Type, forKey key: K) throws -> String? { return self.contains(key) ? try decode(type, forKey: key) : nil }
    func decodeIfPresent<T>(_ type: T.Type, forKey key: K) throws -> T? where T: Decodable { return self.contains(key) ? try decode(T.self, forKey: key) : nil }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let sub = subdecoder(codingPath: codingPath + [key], storage: try decoder.storage.object(forKey: key, context: codingPath + [key]))
        
        return try sub.container(keyedBy: NestedKey.self)
    }
    
    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        let sub = subdecoder(codingPath: codingPath + [key], storage: try decoder.storage.array(forKey: key, context: codingPath + [key]))

        return try sub.unkeyedContainer()
    }
    
    func superDecoder() throws -> Decoder {
        return subdecoder(codingPath: codingPath, storage: decoder.storage)
    }
    
    func superDecoder(forKey key: K) throws -> Decoder {
        return subdecoder(codingPath: codingPath + [key], storage: decoder.storage)
    }
    
}

final class _XMLRPCUnkeyedDecodingContainer: UnkeyedDecodingContainer, SingleValueDecodingContainer {
    let decoder: _XMLRPCDecoder
    
    private func subdecoder(codingPath: [CodingKey], storage: _XMLRPCDecodingStorage) -> _XMLRPCDecoder {
        return _XMLRPCDecoder(
            userInfo: decoder.userInfo,
            codingPath: codingPath,
            autoUnwrap: decoder.autoUnwrap,
            storage: storage
        )
    }
    
    var nextKey: CodingKey { return _XMLRPCCodingKey(intValue: self.currentIndex)! }
    
    init(referencing: _XMLRPCDecoder, codingPath: [CodingKey]) throws {
        self.decoder = referencing
        self.codingPath = codingPath
        self.count = try decoder.storage.assertIsArray(context: codingPath).count
    }
    
    public var count: Int?
    public var currentIndex: Int = 0
    public var isAtEnd: Bool { return currentIndex >= count! }
    public var codingPath: [CodingKey]
    
    func decodeNil() -> Bool {
        fatalError("XML-RPC does not support nil")
    }
    
//    func decodeNil() throws -> Bool {
//        throw DecodingError.typeMismatch(NSNull.self, .init(codingPath: codingPath, debugDescription: "XML-RPC does not support nil"))
//    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let key = nextKey
        currentIndex += 1
        let sub = subdecoder(codingPath: codingPath + [key], storage: try decoder.storage.item(forKey: key, context: codingPath + [key]))
        
        return try T(from: sub)
    }
    
    func decodeIfPresent(_ type: Int.Type) throws -> Int? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: Int8.Type) throws -> Int8? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: Int16.Type) throws -> Int16? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: Int32.Type) throws -> Int32? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: Int64.Type) throws -> Int64? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: UInt.Type) throws -> UInt? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: UInt8.Type) throws -> UInt8? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: UInt16.Type) throws -> UInt16? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: UInt32.Type) throws -> UInt32? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: UInt64.Type) throws -> UInt64? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: Float.Type) throws -> Float? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: Double.Type) throws -> Double? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: Bool.Type) throws -> Bool? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent(_ type: String.Type) throws -> String? { return self.isAtEnd ? nil : try decode(type) }
    func decodeIfPresent<T>(_ type: T.Type) throws -> T? where T: Decodable { return self.isAtEnd ? nil : try self.decode(type) }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let key = nextKey
        currentIndex += 1
        let sub = subdecoder(codingPath: codingPath + [key], storage: try decoder.storage.object(forKey: key, context: codingPath + [key]))
        
        return try sub.container(keyedBy: NestedKey.self)
    }
    
    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let key = nextKey
        currentIndex += 1
        let sub = subdecoder(codingPath: codingPath + [key], storage: try decoder.storage.array(forKey: key, context: codingPath + [key]))
        
        return try sub.unkeyedContainer()
    }
    
    func superDecoder() -> Decoder {
        return subdecoder(codingPath: codingPath, storage: decoder.storage)
    }
}

final class _XMLRPCSingleValueDecodingContainer: SingleValueDecodingContainer {
    let decoder: _XMLRPCDecoder
    
    init(referencing: _XMLRPCDecoder, codingPath: [CodingKey]) {
        self.decoder = referencing
        self.codingPath = codingPath
    }
    
    public var codingPath: [CodingKey]

    func decodeNil() -> Bool {
        fatalError("XML-RPC does not support nil")
    }

    func decode(_ type: Bool.Type) throws -> Bool { return try decoder.storage.assertIsType(type, context: codingPath) }
    func decode(_ type: Int.Type) throws -> Int { return try decoder.storage.assertIsIntType(type, context: codingPath) }
    func decode(_ type: Int8.Type) throws -> Int8 { return try decoder.storage.assertIsIntType(type, context: codingPath) }
    func decode(_ type: Int16.Type) throws -> Int16 { return try decoder.storage.assertIsIntType(type, context: codingPath) }
    func decode(_ type: Int32.Type) throws -> Int32 { return try decoder.storage.assertIsIntType(type, context: codingPath) }
    func decode(_ type: Int64.Type) throws -> Int64 { return try decoder.storage.assertIsIntType(type, context: codingPath) }
    func decode(_ type: UInt.Type) throws -> UInt { return try decoder.storage.assertIsIntType(type, context: codingPath) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { return try decoder.storage.assertIsIntType(type, context: codingPath) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { return try decoder.storage.assertIsIntType(type, context: codingPath) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { return try decoder.storage.assertIsIntType(type, context: codingPath) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { return try decoder.storage.assertIsIntType(type, context: codingPath) }
    func decode(_ type: Float.Type) throws -> Float { return try decoder.storage.assertIsFloatingPointType(context: codingPath) }
    func decode(_ type: Double.Type) throws -> Double { return try decoder.storage.assertIsType(type, context: codingPath) }
    func decode(_ type: String.Type) throws -> String { return try decoder.storage.assertIsType(type, context: codingPath) }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let subdecoder = _XMLRPCDecoder(userInfo: decoder.userInfo, codingPath: codingPath, autoUnwrap: decoder.autoUnwrap, storage: decoder.storage)
        
        return try T(from: subdecoder)
    }
}
