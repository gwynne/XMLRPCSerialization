//
//  XMLRPCSerialization.swift
//  XMLRPCSerialization
//
//  Created by Gwynne Raskind on 12/16/17.
//

import Foundation

public struct XMLRPCRequest {
    public let methodName: String
    public let params: [Any]
    
    public init(methodName: String, params: [Any]) {
        self.methodName = methodName
        self.params = params
    }
}

public enum XMLRPCResponse {
    case fault(code: Int32, string: String)
    case response([Any])
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
        case rootNotMethodResponse
        case noMethodNameElement
        case noParamsElement
        case noValueElement
        case badValueChildren
        case invalidIntValue
        case invalidDateValue
        case invalidBase64Value
        case invalidDoubleValue
        case invalidBooleanValue
        case badMemberElement
        case unknownType
        case badDataElement
        case badFaultResponse
        case badMethodResponse
        
        case unencodableParam
        case encodingError
        
        case unimplemented
    }
    
    /// Parse an object from `Data` containing an XMLRPC request.
    open class func xmlrpcRequest(from data: Data, options opt: ReadingOptions = []) throws -> XMLRPCRequest {
        let doc = try XMLDocument(data: data, options: .nodeLoadExternalEntitiesNever)
        guard let root = doc.rootElement() else {
            throw SerializationError.noRootElement
        }
        guard let name = root.name, name == "methodCall" else {
            throw SerializationError.rootNotMethodCall
        }
        guard
            let methodNameElement = root.elements(forName: "methodName").first,
            let method = methodNameElement.stringValue
        else {
            throw SerializationError.noMethodNameElement
        }
        
        var params: [Any] = []
        let decoder = XMLRPCParamDecoder()
        
        guard let paramsElement = root.elements(forName: "params").first else {
            throw SerializationError.noParamsElement
        }
        for paramElement in paramsElement.elements(forName: "param") {
            params.append(try decoder.decode(from: paramElement))
        }
        return XMLRPCRequest(methodName: method, params: params)
    }
    
    /// Parse an object from `Data` containing an XMLRPC response.
    open class func xmlrpcResponse(from data: Data, options opt: ReadingOptions = []) throws -> XMLRPCResponse {
        let doc = try XMLDocument(data: data, options: .nodeLoadExternalEntitiesNever)
        guard let root = doc.rootElement() else {
            throw SerializationError.noRootElement
        }
        guard let name = root.name, name == "methodResponse", root.childCount == 1 else {
            throw SerializationError.rootNotMethodResponse
        }
        guard let child = root.child(at: 0) as? XMLElement, let childName = child.name else {
            throw SerializationError.rootNotMethodResponse
        }

        let decoder = XMLRPCParamDecoder()

        if childName == "fault" {
            guard child.childCount == 1, let paramElement = child.child(at: 0) as? XMLElement else {
                throw SerializationError.badFaultResponse
            }
            let rawFault = try decoder.decodeValue(paramElement)
            
            guard let rawFaultObj = rawFault as? [String: Any] else {
                throw SerializationError.badFaultResponse
            }
            let realFaultCode: Int32
            if let faultCodeInt = rawFaultObj["faultCode"] as? Int {
                guard let faultCode = Int32(exactly: faultCodeInt) else {
                    throw SerializationError.badFaultResponse
                }
                realFaultCode = faultCode
            } else if let faultCodeUInt = rawFaultObj["faultCode"] as? UInt {
                guard let faultCode = Int32(exactly: faultCodeUInt) else {
                    throw SerializationError.badFaultResponse
                }
                realFaultCode = faultCode
            } else {
                throw SerializationError.badFaultResponse
            }
            guard let faultString = rawFaultObj["faultString"] as? String else {
                throw SerializationError.badFaultResponse
            }
            return XMLRPCResponse.fault(code: realFaultCode, string: faultString)
        } else if childName == "params" {
            var params: [Any] = []
        
            for paramNode in child.children ?? [] {
                guard let paramElement = paramNode as? XMLElement else {
                    throw SerializationError.badMethodResponse
                }
                params.append(try decoder.decode(from: paramElement))
            }
            return XMLRPCResponse.response(params)
        } else {
            throw SerializationError.rootNotMethodResponse
        }
    }
    
    /// Generate a serialized XML string from an XMLRPCRequest object.
    /// Does not generate `Data` because there's no good way to convert a
    /// `String.Encoding` to its equivalent display name in an XML declaration.
    open class func string(withXmlrpcRequest obj: XMLRPCRequest, options opt: WritingOptions = []) throws -> String {
        let nameElement = XMLElement(name: "methodName", content: obj.methodName)
        let paramsElement = XMLElement(name: "params")
        let rootElement = XMLElement(name: "methodCall", wrapping: [nameElement, paramsElement])
        let encoder = XMLRPCParamEncoder()
        
        for param in obj.params {
            paramsElement.addChild(try encoder.encode(param))
        }

        var options: XMLNode.Options = []
        if opt.contains(.prettyPrint) {
            options.update(with: .nodePrettyPrint)
        }
        return rootElement.xmlString(options: options)
    }

    /// Generate a serialized XML string from an XMLRPCResponse object.
    /// Does not generate `Data` because there's no good way to convert a
    /// `String.Encoding` to its equivalent display name in an XML declaration.
    open class func string(withXmlrpcResponse obj: XMLRPCResponse, options opt: WritingOptions = []) throws -> String {
        let rootElement = XMLElement(name: "methodResponse")
        let encoder = XMLRPCParamEncoder()
        
        switch obj {
            case .response(let params):
                let paramsElement = XMLElement(name: "params")
                
                rootElement.addChild(paramsElement)
                for param in params {
                    paramsElement.addChild(try encoder.encode(param))
                }
            case .fault(let code, let string):
                let faultElement = XMLElement(name: "fault")
                let rawFault: [(String, Any)] = [("faultCode", code), ("faultString", string)]
                
                rootElement.addChild(faultElement)
                faultElement.addChild(try encoder.encodeValue(rawFault))
        }

        var options: XMLNode.Options = []
        if opt.contains(.prettyPrint) {
            options.update(with: .nodePrettyPrint)
        }
        return rootElement.xmlString(options: options)
    }
}
