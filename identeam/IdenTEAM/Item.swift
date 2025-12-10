//
//  Item.swift
//  identeam
//
//  Created by Nico Stern on 23.11.25.
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
