import SwiftUI

extension AddGlucose {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var glucoseStorage: GlucoseStorage!
        @Published var glucose: Decimal = 0
        @Published var date = Date()
        @Published var units: GlucoseUnits = .mmolL

        override func subscribe() {
            units = settingsManager.settings.units
        }

        func add() {
            guard glucose > 0 else {
                showModal(for: nil)
                return
            }

            // Convert to mg/dL if needed (storage uses mg/dL internally)
            let glucoseInMgdL: Int
            if units == .mmolL {
                glucoseInMgdL = Int(glucose.asMgdL)
            } else {
                glucoseInMgdL = Int(glucose)
            }

            let entry = BloodGlucose(
                sgv: glucoseInMgdL,
                direction: .none,
                date: Decimal(date.timeIntervalSince1970 * 1000),
                dateString: date,
                unfiltered: nil,
                filtered: nil,
                noise: nil,
                glucose: glucoseInMgdL,
                type: "manual"
            )

            glucoseStorage.storeGlucose([entry])
            showModal(for: nil)
        }
    }
}
