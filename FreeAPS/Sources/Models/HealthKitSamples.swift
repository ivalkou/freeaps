import Foundation

// MARK: - Blood glucose

struct HealthKitBGSample: JSON, Hashable, Equatable {
    var healthKitId: String
    var date: Date
    var glucose: Int

    static func == (lhs: HealthKitBGSample, rhs: HealthKitBGSample) -> Bool {
        lhs.healthKitId == rhs.healthKitId
    }
}

extension HealthKitBGSample {
    private enum CodingKeys: String, CodingKey {
        case healthKitId = "healthkit_id"
        case date
        case glucose
    }
}

// MARK: - Carbs

struct HealthKitCarbsSample: JSON, Hashable, Equatable {
    var healthKitId: String
    var date: Date
    var carbs: Decimal

    static func == (lhs: HealthKitCarbsSample, rhs: HealthKitCarbsSample) -> Bool {
        lhs.healthKitId == rhs.healthKitId
    }
}

extension HealthKitCarbsSample {
    private enum CodingKeys: String, CodingKey {
        case healthKitId = "healthkit_id"
        case date
        case carbs
    }
}
