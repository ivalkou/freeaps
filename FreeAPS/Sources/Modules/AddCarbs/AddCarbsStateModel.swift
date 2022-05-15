import SwiftUI

extension AddCarbs {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var carbsStorage: CarbsStorage!
        @Injected() var apsManager: APSManager!
        @Injected() var healthKitManager: HealthKitManager!
        @Published var ID: String = UUID().uuidString
        @Published var carbs: Decimal = 0
        @Published var date = Date()
        @Published var carbsRequired: Decimal?

        override func subscribe() {
            carbsRequired = provider.suggestion?.carbsReq
        }

        func add() {
            guard carbs > 0 else {
                showModal(for: nil)
                return
            }

            let carbArray = [
                CarbsEntry(id: ID, createdAt: date, carbs: carbs, enteredBy: CarbsEntry.manual)
            ]
            carbsStorage.storeCarbs(carbArray)
            healthKitManager.saveIfNeeded(carbs: carbArray)

            if settingsManager.settings.skipBolusScreenAfterCarbs {
                apsManager.determineBasalSync()
                showModal(for: nil)
            } else {
                showModal(for: .bolus(waitForSuggestion: true))
            }
        }
    }
}
