import Foundation

/// Позиция списка покупок, найденная в холодильнике.
struct MatchedItem: Equatable {
    let item: String
    let matchedAs: String
}

/// Итог сопоставления списка покупок с тем, что нашлось в холодильнике.
struct ShoppingMatch {
    /// Позиции из списка, которые уже есть дома (с тем, как их распознала модель).
    let alreadyHave: [MatchedItem]
    /// Позиции из списка, которые всё ещё нужно купить.
    let stillNeeded: [String]
    /// Распознанные продукты, которых не было в списке покупок.
    let otherRecognized: [String]
}

enum ProductMatcher {
    /// Нормализация русских названий: регистр, «ё», пунктуация, лишние пробелы.
    static func normalize(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Два названия считаются одним продуктом, если совпадают полностью
    /// или одно содержит другое (для вариантов «сыр» / «сыр твёрдый»).
    static func isMatch(_ lhs: String, _ rhs: String) -> Bool {
        let a = normalize(lhs)
        let b = normalize(rhs)
        guard !a.isEmpty, !b.isEmpty else { return false }
        if a == b { return true }
        let shorter = a.count <= b.count ? a : b
        let longer = a.count <= b.count ? b : a
        return shorter.count >= 3 && longer.contains(shorter)
    }

    static func match(shoppingList: [String], recognized: [String]) -> ShoppingMatch {
        var alreadyHave: [MatchedItem] = []
        var stillNeeded: [String] = []
        var usedRecognized = Set<Int>()

        for item in shoppingList {
            if let index = recognized.indices.first(where: { !usedRecognized.contains($0) && isMatch(item, recognized[$0]) }) {
                alreadyHave.append(MatchedItem(item: item, matchedAs: recognized[index]))
                usedRecognized.insert(index)
            } else {
                stillNeeded.append(item)
            }
        }

        let other = recognized.indices
            .filter { !usedRecognized.contains($0) }
            .map { recognized[$0] }

        return ShoppingMatch(alreadyHave: alreadyHave, stillNeeded: stillNeeded, otherRecognized: other)
    }
}
