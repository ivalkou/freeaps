import Foundation

struct RecentCarbPreset: JSON, Identifiable, Equatable, Hashable {
    var id = UUID().uuidString
    let name: String
    let carbs: Decimal

    static func == (lhs: RecentCarbPreset, rhs: RecentCarbPreset) -> Bool {
        lhs.name == rhs.name && lhs.carbs == rhs.carbs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(carbs)
    }
}
