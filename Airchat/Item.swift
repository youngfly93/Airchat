//
//  Item.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
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
