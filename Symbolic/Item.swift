//
//  Item.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/8.
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
