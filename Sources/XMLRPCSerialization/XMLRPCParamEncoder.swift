//
//  XMLRPCParamEncoder.swift
//  XMLRPCSerialization
//
//  Created by Gwynne Raskind on 12/16/17.
//

import Foundation

open class XMLRPCParamEncoder {
    
    public init() {}
    
    open func encode(_ value: Any) throws -> XMLElement {
        let wrapper = XMLElement(name: "param")
        
        wrapper.addChild(try encodeValue(value))
        return wrapper
    }
    
    internal func encodeValue(_ value: Any) throws -> XMLElement {
        let wrapper = XMLElement(name: "value")
        
        wrapper.addChild(try encodeType(value))
        return wrapper
    }
    
    private func encodeType(_ value: Any) throws -> XMLElement {
        if let value = value as? String {
            return XMLElement(name: "string", content: value)
        } else if let value = value as? Int {
            return XMLElement(name: "i4", content: String(value))
        } else if let value = value as? Int8 {
            return XMLElement(name: "i4", content: String(value))
        } else if let value = value as? Int16 {
            return XMLElement(name: "i4", content: String(value))
        } else if let value = value as? Int32 {
            return XMLElement(name: "i4", content: String(value))
        } else if let value = value as? Int64 {
            return XMLElement(name: "i4", content: String(value))
        } else if let value = value as? UInt {
            return XMLElement(name: "i4", content: String(value))
        } else if let value = value as? UInt8 {
            return XMLElement(name: "i4", content: String(value))
        } else if let value = value as? UInt16 {
            return XMLElement(name: "i4", content: String(value))
        } else if let value = value as? UInt32 {
            return XMLElement(name: "i4", content: String(value))
        } else if let value = value as? UInt64 {
            return XMLElement(name: "i4", content: String(value))
        } else if let value = value as? Float {
            return XMLElement(name: "double", content: String(value))
        } else if let value = value as? Double {
            return XMLElement(name: "double", content: String(value))
        } else if let value = value as? Bool {
            return XMLElement(name: "boolean", content: value ? "1" : "0")
        } else if let value = value as? Date {
            return XMLElement(name: "dateTime.iso8601", content: sharedIso8601Formatter.string(from: value))
        } else if let value = value as? Data {
            return XMLElement(name: "base64", content: value.base64EncodedString(options: []))
        } else if let value = value as? [(String, Any)] {
            let wrapper = XMLElement(name: "struct")
            for (key, subvalue) in value {
                wrapper.addChild(XMLElement(name: "member", wrapping: [XMLElement(name: "name", content: key), try encodeValue(subvalue)]))
            }
            return wrapper
        } else if let value = value as? [String: Any] {
            let wrapper = XMLElement(name: "struct")
            for (key, subvalue) in value {
                wrapper.addChild(XMLElement(name: "member", wrapping: [XMLElement(name: "name", content: key), try encodeValue(subvalue)]))
            }
            return wrapper
        } else if let value = value as? [Any] {
            let wrapper = XMLElement(name: "data")
            let wideWrapper = XMLElement(name: "array", wrapping: [wrapper])
            for subvalue in value {
                wrapper.addChild(try encodeValue(subvalue))
            }
            return wideWrapper
        } else {
            throw XMLRPCSerialization.SerializationError.unknownType
        }
    }
}

