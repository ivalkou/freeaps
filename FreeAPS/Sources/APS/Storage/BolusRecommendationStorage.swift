import Foundation
import Swinject

protocol BolusRecommendationStorage {
    func storeRecommendation(_ recommendation: Decimal, at date: Date)
    func getRecommendation(forBolusId id: String) -> Decimal?
    func matchRecommendation(forBolusId id: String, bolusDate: Date, tolerance: TimeInterval) -> Decimal?
    func cleanup()
}

final class BaseBolusRecommendationStorage: BolusRecommendationStorage, Injectable {
    private let processQueue = DispatchQueue(label: "BaseBolusRecommendationStorage.processQueue")
    @Injected() private var storage: FileStorage!

    private struct StoredRecommendation: JSON, Equatable {
        let recommendation: Decimal
        let date: Date
        var bolusId: String?
    }

    init(resolver: Resolver) {
        injectServices(resolver)
    }

    func storeRecommendation(_ recommendation: Decimal, at date: Date) {
        processQueue.sync {
            var recommendations = self.loadRecommendations()
            recommendations.append(StoredRecommendation(recommendation: recommendation, date: date, bolusId: nil))
            self.saveRecommendations(recommendations)
            self.performCleanup()
        }
    }

    func getRecommendation(forBolusId id: String) -> Decimal? {
        processQueue.sync {
            let recommendations = loadRecommendations()
            return recommendations.first { $0.bolusId == id }?.recommendation
        }
    }

    func matchRecommendation(forBolusId id: String, bolusDate: Date, tolerance: TimeInterval) -> Decimal? {
        processQueue.sync {
            var recommendations = loadRecommendations()

            // First, check if this bolus already has a matched recommendation
            if let existing = recommendations.first(where: { $0.bolusId == id }) {
                return existing.recommendation
            }

            // Find closest unmatched recommendation by time
            let unmatched = recommendations.filter { $0.bolusId == nil }
            guard let closest = unmatched
                .filter({ abs($0.date.timeIntervalSince(bolusDate)) <= tolerance })
                .min(by: { abs($0.date.timeIntervalSince(bolusDate)) < abs($1.date.timeIntervalSince(bolusDate)) })
            else {
                return nil
            }

            // Mark this recommendation as matched to this bolus
            if let index = recommendations.firstIndex(where: { $0.date == closest.date && $0.bolusId == nil }) {
                recommendations[index].bolusId = id
                saveRecommendations(recommendations)
            }

            return closest.recommendation
        }
    }

    func cleanup() {
        processQueue.async {
            self.performCleanup()
        }
    }

    private func performCleanup() {
        let cutoff = Date().addingTimeInterval(-25 * 60 * 60) // 25 hours
        var recommendations = loadRecommendations()
        recommendations.removeAll { $0.date < cutoff }
        saveRecommendations(recommendations)
    }

    private func loadRecommendations() -> [StoredRecommendation] {
        storage.retrieve(OpenAPS.FreeAPS.bolusRecommendations, as: [StoredRecommendation].self) ?? []
    }

    private func saveRecommendations(_ recommendations: [StoredRecommendation]) {
        storage.save(recommendations, as: OpenAPS.FreeAPS.bolusRecommendations)
    }
}
