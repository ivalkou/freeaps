import Foundation

struct CarbsEntry: JSON, Equatable, Hashable {
    var id = UUID().uuidString
    let createdAt: Date
    let carbs: Decimal
    let enteredBy: String?

    static let manual = "freeaps-x"
    static let applehealth = "applehealth"

    static func == (lhs: CarbsEntry, rhs: CarbsEntry) -> Bool {
        lhs.createdAt == rhs.createdAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(createdAt)
    }
}

extension CarbsEntry {
    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case createdAt = "created_at"
        case carbs
        case enteredBy
    }
}

// MARK: CarbsEntry till 0.2.6

// At this version was add id propery for working with Apple Health
struct CarbsEntryTill026: JSON, Equatable, Hashable {
    let createdAt: Date
    let carbs: Decimal
    let enteredBy: String?

    static let manual = "freeaps-x"

    static func == (lhs: CarbsEntryTill026, rhs: CarbsEntryTill026) -> Bool {
        lhs.createdAt == rhs.createdAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(createdAt)
    }
}

extension CarbsEntryTill026 {
    private enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case carbs
        case enteredBy
    }
}
