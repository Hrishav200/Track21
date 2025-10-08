//
//  Item.swift
//  Track21
//
//  Created by Hrishav Sunar on 8/10/2025.
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
