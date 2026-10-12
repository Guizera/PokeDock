//
//  Item.swift
//  pokeTab
//
//  Created by José Alves da Cunha on 12/10/26.
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
