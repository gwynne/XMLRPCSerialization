//
//  XMLElement+Convenience.swift
//  XMLRPCSerialization
//
//  Created by Gwynne Raskind on 12/16/17.
//

import Foundation

extension XMLElement {
    convenience init(name: String, content: String) {
        self.init(name: name, wrapping: XMLNode.text(withStringValue: content) as! XMLNode)
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
