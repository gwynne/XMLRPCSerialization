//
//  XMLRPCParamEncoder.swift
//  XMLRPCSerialization
//
//  Created by Gwynne Raskind on 12/16/17.
//

import Foundation

open class XMLRPCParamEncoder {
    
    open var userInfo: [CodingUserInfoKey: Any] = [:]
    
    public init() {}
    
    open func encode<T>(_ value: T) throws -> XMLElement where T: Encodable {
        let encoder = _XMLRPCParamEncoder(userInfo: userInfo)
        let wrapper = XMLElement(name: "param")
        
        try value.encode(to: encoder)
        wrapper.addChild(encoder.result)
        return wrapper
    }
    
    open var directEncoder: XMLRPCParamDirectEncoder {
        return _XMLRPCParamEncoder(userInfo: self.userInfo)
    }
}

public protocol XMLRPCParamDirectEncoder: Encoder {
    var output: XMLElement { get }
}

extension DateFormatter {
    public static var iso8601DateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }
}

private var formatter = DateFormatter.iso8601DateFormatter

extension Array where Element == CodingKey {
    var printable: String { return self.map { $0.stringValue }.joined(separator: ".") }
}

class _XMLRPCParamEncoder: Encoder, XMLRPCParamDirectEncoder {
    
    let result = XMLElement(name: "value")
    var alreadyRequestedContainer = false
    
    var output: XMLElement { return XMLElement(name: "param", wrapping: result) }
    
    init(userInfo: [CodingUserInfoKey: Any], codingPath: [CodingKey] = []) {
        self.userInfo = userInfo
        self.codingPath = codingPath
    }
    
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey : Any]
    
    fileprivate func with<T>(pushedKey key: CodingKey, _ work: () throws -> T) rethrows -> T {
        self.codingPath.append(key)
        let ret = try work()
        self.codingPath.removeLast()
        return ret
    }
    
    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        precondition(!alreadyRequestedContainer, "Can't request multiple containers from an encoder")
        alreadyRequestedContainer = true
        
        let (node, container) = containerForEncoding(keyedBy: type)
        result.addChild(node)
        return .init(container)
    }
    
    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        precondition(!alreadyRequestedContainer, "Can't request multiple containers from an encoder")
        alreadyRequestedContainer = true
        
        let (node, container) = unkeyedContainerForEncoding()
        result.addChild(node)
        return container
    }
    
    public func singleValueContainer() -> SingleValueEncodingContainer {
        precondition(!alreadyRequestedContainer, "Can't request multiple containers from an encoder")
        alreadyRequestedContainer = true
        
        return singleValueContainerForEncoding()
    }
    
    fileprivate func containerForEncoding<Key: CodingKey>(keyedBy type: Key.Type) -> (XMLNode, _XMLRPCParamKeyedEncodingContainer<Key>) {
        let structWrapper = XMLElement(name: "struct")
        return (structWrapper, _XMLRPCParamKeyedEncodingContainer<Key>(referencing: self, codingPath: self.codingPath, storage: structWrapper))
    }
    
    fileprivate func unkeyedContainerForEncoding() -> (XMLNode, _XMLRPCParamUnkeyedEncodingContainer) {
        let dataWrapper = XMLElement(name: "data")
        let arrayWrapper = XMLElement(name: "array", wrapping: dataWrapper)
        return (arrayWrapper, _XMLRPCParamUnkeyedEncodingContainer(referencing: self, codingPath: self.codingPath, storage: dataWrapper))
    }
    
    fileprivate func singleValueContainerForEncoding() -> _XMLRPCParamSingleValueEncodingContainer {
        return _XMLRPCParamSingleValueEncodingContainer(referencing: self, codingPath: self.codingPath, storage: result)
    }
}

fileprivate class _XMLRPCParamKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K
    
    private let encoder: _XMLRPCParamEncoder
    private let storage: XMLElement
    
    init(referencing: _XMLRPCParamEncoder, codingPath: [CodingKey], storage: XMLElement) {
        self.encoder = referencing
        self.codingPath = codingPath
        self.storage = storage
    }
    
    public var codingPath: [CodingKey]
    
    public func encodeNil(forKey key: K) throws {
        encoder.with(pushedKey: key) {
            let valueWrapper = XMLElement(name: "value", wrapping: XMLElement(name: "nil"))
            let nameWrapper = XMLElement(name: "name", content: key.stringValue)
            let memberWrapper = XMLElement(name: "member", wrapping: [nameWrapper, valueWrapper])

            storage.addChild(memberWrapper)
        }
    }
    
    public func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
        try encoder.with(pushedKey: key) {
            let valueWrapper: XMLElement
            if let value = value as? Data {
                valueWrapper = XMLElement(name: "value", wrapping: XMLElement(name: "base64", content: value.base64EncodedString()))
            } else if let value = value as? Date {
                valueWrapper = XMLElement(name: "value", wrapping: XMLElement(name: "dateTime.iso8601", content: formatter.string(from: value)))
            } else {
                let subencoder = _XMLRPCParamEncoder(userInfo: encoder.userInfo, codingPath: encoder.codingPath)
                
                try value.encode(to: subencoder)
                valueWrapper = subencoder.result
            }
            let nameWrapper = XMLElement(name: "name", content: key.stringValue)
            let memberWrapper = XMLElement(name: "member", wrapping: [nameWrapper, valueWrapper])
            storage.addChild(memberWrapper)
        }
    }
    
    public func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> {
        return encoder.with(pushedKey: key) {
            return .init(_XMLRPCParamEncoder(userInfo: encoder.userInfo, codingPath: encoder.codingPath).container(keyedBy: NestedKey.self))
        }
    }
    
    public func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        return encoder.with(pushedKey: key) {
            return _XMLRPCParamEncoder(userInfo: encoder.userInfo, codingPath: encoder.codingPath).unkeyedContainer()
        }
    }
    
    public func superEncoder() -> Encoder {
        return encoder
    }
    
    public func superEncoder(forKey key: K) -> Encoder {
        return encoder.with(pushedKey: key) { superEncoder() }
    }
}

fileprivate class _XMLRPCParamUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    
    private let encoder: _XMLRPCParamEncoder
    private let storage: XMLElement
    
    init(referencing: _XMLRPCParamEncoder, codingPath: [CodingKey], storage: XMLElement) {
        self.encoder = referencing
        self.codingPath = codingPath
        self.storage = storage
    }

    public var codingPath: [CodingKey]
    
    public var count: Int {
        return storage.childCount
    }
    
    public func encodeNil() throws {
        storage.addChild(XMLElement(name: "value", wrapping: XMLElement(name: "nil")))
    }
    
    public func encode<T>(_ value: T) throws where T : Encodable {
        let valueWrapper: XMLElement
        if let value = value as? Data {
            valueWrapper = XMLElement(name: "value", wrapping: XMLElement(name: "base64", content: value.base64EncodedString()))
        } else if let value = value as? Date {
            valueWrapper = XMLElement(name: "value", wrapping: XMLElement(name: "dateTime.iso8601", content: formatter.string(from: value)))
        } else {
            let subencoder = _XMLRPCParamEncoder(userInfo: encoder.userInfo, codingPath: encoder.codingPath)
            try value.encode(to: subencoder)
            valueWrapper = subencoder.result
        }
        storage.addChild(valueWrapper)
    }
    
    public func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        return .init(_XMLRPCParamEncoder(userInfo: encoder.userInfo, codingPath: encoder.codingPath).container(keyedBy: NestedKey.self))
    }
    
    public func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return _XMLRPCParamEncoder(userInfo: encoder.userInfo, codingPath: encoder.codingPath).unkeyedContainer()
    }
    
    public func superEncoder() -> Encoder {
        return encoder
    }
}

fileprivate class _XMLRPCParamSingleValueEncodingContainer: SingleValueEncodingContainer {
    private let encoder: _XMLRPCParamEncoder
    private let storage: XMLElement
    
    init(referencing: _XMLRPCParamEncoder, codingPath: [CodingKey], storage: XMLElement) {
        self.encoder = referencing
        self.codingPath = codingPath
        self.storage = storage
    }

    public var codingPath: [CodingKey]

    public func encodeNil() throws {
        storage.addChild(XMLElement(name: "nil"))
    }
    
    public func encode(_ value: Bool) throws {
        storage.addChild(XMLElement(name: "boolean", content: "\(value ? 1 : 0)"))
    }
    
    public func encode(_ value: Int) throws {
        storage.addChild(XMLElement(name: "int", content: String(value)))
    }
    public func encode(_ value: Int8) throws {
        storage.addChild(XMLElement(name: "int", content: String(value)))
    }
    public func encode(_ value: Int16) throws {
        storage.addChild(XMLElement(name: "int", content: String(value)))
    }
    public func encode(_ value: Int32) throws {
        storage.addChild(XMLElement(name: "int", content: String(value)))
    }
    public func encode(_ value: Int64) throws {
        storage.addChild(XMLElement(name: "int", content: String(value)))
    }
    public func encode(_ value: UInt) throws {
        storage.addChild(XMLElement(name: "int", content: String(value)))
    }
    public func encode(_ value: UInt8) throws {
        storage.addChild(XMLElement(name: "int", content: String(value)))
    }
    public func encode(_ value: UInt16) throws {
        storage.addChild(XMLElement(name: "int", content: String(value)))
    }
    public func encode(_ value: UInt32) throws {
        storage.addChild(XMLElement(name: "int", content: String(value)))
    }
    public func encode(_ value: UInt64) throws {
        storage.addChild(XMLElement(name: "int", content: String(value)))
    }
    public func encode(_ value: Float) throws {
        storage.addChild(XMLElement(name: "double", content: String(value)))
    }
    public func encode(_ value: Double) throws {
        storage.addChild(XMLElement(name: "double", content: String(value)))
    }
    public func encode(_ value: String) throws {
        storage.addChild(XMLElement(name: "string", content: value))
    }
    public func encode<T>(_ value: T) throws where T : Encodable {
        if let value = value as? Data {
            storage.addChild(XMLElement(name: "base64", content: value.base64EncodedString()))
        } else if let value = value as? Date {
            storage.addChild(XMLElement(name: "dateTime.iso8601", content: formatter.string(from: value)))
        } else {
            let subencoder = _XMLRPCParamEncoder(userInfo: encoder.userInfo, codingPath: encoder.codingPath)
            try value.encode(to: subencoder)
            if let children = subencoder.result.children {
                storage.insertChildren(children, at: 0)
            }
        }
    }
}
