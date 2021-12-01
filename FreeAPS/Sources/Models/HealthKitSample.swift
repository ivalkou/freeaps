import Foundation

struct HealthKitSample: JSON, Hashable, Equatable {
    var healthKitId: String

    static func == (lhs: HealthKitSample, rhs: HealthKitSample) -> Bool {
        lhs.healthKitId == rhs.healthKitId
    }
}

extension HealthKitSample {
    private enum CodingKeys: String, CodingKey {
        case healthKitId = "healthkit_id"
    }
}
