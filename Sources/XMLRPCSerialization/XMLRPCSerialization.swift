//
//  XMLRPCSerialization.swift
//  XMLRPCSerialization
//
//  Created by Gwynne Raskind on 12/16/17.
//

import Foundation

public struct XMLRPCRequest {
    public let methodName: String
    public let params: [Codable]
}

open class XMLRPCSerialization {
    
    public struct ReadingOptions: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
    }
    
    public struct WritingOptions: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        
        public static let prettyPrint = WritingOptions(rawValue: 1 << 0)
    }
    
    public enum SerializationError: Error {
        case noRootElement
        case rootNotMethodCall
        case noMethodNameElement
        case noParamsElement
        
        case unencodableParam
        case encodingError
        
        case unimplemented
    }
    
    /// Parse an object from `Data` containing an XMLRPC request.
    ///
    /// - Note: This parsing logic is very lax - it does not validate that the
    /// XML structure is fully correct, just that the necessary elements are
    /// present in readable fashion.
    open class func xmlrpcObject(with data: Data, options opt: ReadingOptions = []) throws -> XMLRPCRequest {
//        let doc = try XMLDocument(data: data, options: .nodeLoadExternalEntitiesNever)
//        guard let root = doc.rootElement() else {
//            throw SerializationError.noRootElement
//        }
//        guard let name = root.name, name == "methodCall" else {
//            throw SerializationError.rootNotMethodCall
//        }
//        guard
//            let methodNameElement = root.elements(forName: "methodName").first,
//            methodNameElement.childCount == 1,
//            let methodNameText = methodNameElement.child(at: 0),
//            case .text = methodNameText.kind,
//            let method = methodNameText.stringValue
//        else {
//            throw SerializationError.noMethodNameElement
//        }
//
//        guard let paramsElement = root.elements(forName: "params").first else {
//            throw SerializationError.noParamsElement
//        }
//        for paramElement in paramsElement.elements(forName: "param") {
//
//        }
        throw SerializationError.unimplemented
    }
    
    /// Generate serialized `Data` from an XMLRPCRequest object.
    open class func data(withXmlrpcObject obj: XMLRPCRequest, encoding enc: String.Encoding = .utf8, options opt: WritingOptions = []) throws -> Data {
        let nameElement = XMLElement(name: "methodName", content: obj.methodName)
        let paramsElement = XMLElement(name: "params")
        let rootElement = XMLElement(name: "methodCall", wrapping: [nameElement, paramsElement])
        
        for param in obj.params {
            let encoder = XMLRPCParamEncoder().directEncoder
            
            try param.encode(to: encoder)
            paramsElement.addChild(encoder.output)
        }

        let doc = XMLDocument(rootElement: rootElement)
        var options: XMLDocument.Options = []
        if opt.contains(.prettyPrint) {
            options.update(with: .nodePrettyPrint)
        }
        guard let data = doc.xmlString(options: options).data(using: enc) else {
            throw SerializationError.encodingError
        }
        return data
    }
}

