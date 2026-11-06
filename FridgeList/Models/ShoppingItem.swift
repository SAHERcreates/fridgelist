import Foundation
import SwiftData

/// Продукт, который пользователь планирует купить.
@Model
final class ShoppingItem {
    var name: String
    var addedAt: Date

    init(name: String, addedAt: Date = .now) {
        self.name = name
        self.addedAt = addedAt
    }
}
