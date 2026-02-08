import Foundation

struct EventEntry: JSON, Identifiable, Equatable, Hashable {
    var id = UUID().uuidString
    let name: String
    let createdAt: Date
    let endAt: Date?

    static func == (lhs: EventEntry, rhs: EventEntry) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension EventEntry {
    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case createdAt = "created_at"
        case endAt = "end_at"
    }
}
