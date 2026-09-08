//
//  Item.swift
//  BabyCare
//
//  Created by Vu Thanh Do on 8/9/26.
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
