//
//  XMLElement+Convenience.swift
//  XMLRPCSerialization
//
//  Created by Gwynne Raskind on 12/16/17.
//

import Foundation

extension XMLElement {
    convenience init(name: String, content: String) {
        let textNode = XMLNode(kind: .text)
        textNode.stringValue = content
        self.init(name: name, wrapping: textNode)
    }
    
    convenience init(name: String, wrapping: XMLNode) {
        self.init(name: name)
        self.addChild(wrapping)
    }
    
    convenience init(name: String, wrapping: [XMLNode]) {
        self.init(name: name)
        wrapping.forEach { self.addChild($0) }
    }
}
