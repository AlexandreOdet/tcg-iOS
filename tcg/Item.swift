//
//  Item.swift
//  tcg
//
//  Created by Alexandre Odet on 18/10/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
