import Foundation
import SwiftData

/// Результат одного сканирования холодильника.
@Model
final class ScanRecord {
    var date: Date
    var productNames: [String]

    init(date: Date = .now, productNames: [String]) {
        self.date = date
        self.productNames = productNames
    }
}
