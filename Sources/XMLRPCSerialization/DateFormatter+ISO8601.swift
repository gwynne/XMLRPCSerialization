//
//  DateFormatter+ISO8601.swift
//  XMLRPCSerialization
//
//  Created by Gwynne Raskind on 12/16/17.
//

import Foundation

extension DateFormatter {
    public static var iso8601DateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }
}

internal var sharedIso8601Formatter = DateFormatter.iso8601DateFormatter
