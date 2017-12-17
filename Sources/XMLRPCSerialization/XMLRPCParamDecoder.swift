//
//  XMLRPCParamDecoder.swift
//  XMLRPCSerialization
//
//  Created by Gwynne Raskind on 12/16/17.
//

import Foundation

open class XMLRPCParamDecoder {

    public init() {}

    open func decode(from xml: XMLElement) throws -> Any {
        guard let name = xml.name, name == "param" else {
            throw XMLRPCSerialization.SerializationError.noValueElement
        }
        guard xml.childCount == 1, let child = xml.child(at: 0), let childElement = child as? XMLElement else {
            throw XMLRPCSerialization.SerializationError.badValueChildren
        }
        return try decodeValue(childElement)
    }
    
    private func decodeValue(_ element: XMLElement) throws -> Any {
        guard let name = element.name, name == "value" else {
            throw XMLRPCSerialization.SerializationError.noValueElement
        }
        guard element.childCount == 1, let child = element.child(at: 0), let childElement = child as? XMLElement else {
            throw XMLRPCSerialization.SerializationError.badValueChildren
        }
        return try decodeType(childElement)
    }
    
    private func decodeType(_ element: XMLElement) throws -> Any {
        guard let type = element.name else {
            throw XMLRPCSerialization.SerializationError.badValueChildren
        }
        
        switch type.lowercased() {
            case "string":
                return element.stringValue ?? ""
            case "int", "i4":
                let raw = element.stringValue ?? ""
            
                if let uint = UInt(raw) {
                    return uint
                } else if let int = Int(raw) {
                    return int
                } else {
                    throw XMLRPCSerialization.SerializationError.invalidIntValue
                }
            case "datetime.iso8601":
                guard let date = sharedIso8601Formatter.date(from: element.stringValue ?? "") else {
                    throw XMLRPCSerialization.SerializationError.invalidDateValue
                }
                return date
            case "base64":
                guard let data = Data(base64Encoded: element.stringValue ?? "") else {
                    throw XMLRPCSerialization.SerializationError.invalidBase64Value
                }
                return data
            case "boolean":
                if let v = element.stringValue, v == "0" {
                    return false
                } else if let v = element.stringValue, v == "1" {
                    return true
                } else {
                    throw XMLRPCSerialization.SerializationError.invalidBooleanValue
                }
            case "double":
                guard let double = Double(element.stringValue ?? "") else {
                    throw XMLRPCSerialization.SerializationError.invalidDoubleValue
                }
                return double
            case "struct":
                var members: [String: Any] = [:]
                
                for child in element.children ?? [] {
                    guard let memberElement = child as? XMLElement,
                          let nameElement = memberElement.child(at: 0) as? XMLElement,
                          let valueElement = memberElement.child(at: 1) as? XMLElement,
                          memberElement.childCount == 2,
                          let mname = memberElement.name, mname == "member",
                          let nname = nameElement.name, nname == "name",
                          let vname = valueElement.name, vname == "value",
                    	  let name = nameElement.stringValue
                    else {
                        throw XMLRPCSerialization.SerializationError.badMemberElement
                    }
                    
                    members[name] = try decodeValue(valueElement)
                }
                return members
            case "array":
                var items: [Any] = []
            
                guard element.childCount == 1, let dataElement = element.child(at: 0) as? XMLElement else {
                    throw XMLRPCSerialization.SerializationError.badDataElement
                }
                for child in dataElement.children ?? [] {
                    guard let childElement = child as? XMLElement,
                          let cname = childElement.name,
                          cname == "value"
                    else {
                        throw XMLRPCSerialization.SerializationError.badDataElement
                    }
                    items.append(try decodeValue(childElement))
                }
                return items
            default:
                throw XMLRPCSerialization.SerializationError.unknownType
        }
    }
}
