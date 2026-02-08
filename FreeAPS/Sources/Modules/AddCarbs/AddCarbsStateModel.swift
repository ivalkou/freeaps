import SwiftUI

extension AddCarbs {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var carbsStorage: CarbsStorage!
        @Injected() var apsManager: APSManager!
        @Published var carbs: Decimal = 0
        @Published var date = Date()
        @Published var note: String = ""
        @Published var carbsRequired: Decimal?
        @Published var recentPresets: [RecentCarbPreset] = []
        @Published var isEditingPresets = false

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }

        override func subscribe() {
            carbsRequired = provider.suggestion?.carbsReq
            recentPresets = provider.recentCarbPresets()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        func add() {
            guard carbs > 0 else {
                showModal(for: nil)
                return
            }

            carbsStorage.storeCarbs([
                CarbsEntry(createdAt: date, carbs: carbs, enteredBy: CarbsEntry.manual, note: note.isEmpty ? nil : note)
            ])

            savePresetIfNeeded()
            showModal(for: .bolus(waitForSuggestion: true))
        }

        func fastAdd() {
            guard carbs > 0 else {
                showModal(for: nil)
                return
            }

            carbsStorage.storeCarbs([
                CarbsEntry(createdAt: date, carbs: carbs, enteredBy: CarbsEntry.manual, note: note.isEmpty ? nil : note)
            ])

            savePresetIfNeeded()
            apsManager.determineBasalSync()
            showModal(for: nil)
        }

        func selectPreset(_ preset: RecentCarbPreset) {
            note = preset.name
            carbs = preset.carbs
        }

        func deletePreset(_ preset: RecentCarbPreset) {
            provider.deleteRecentCarbPreset(preset)
            recentPresets.removeAll { $0.name == preset.name && $0.carbs == preset.carbs }
        }

        private func savePresetIfNeeded() {
            guard !note.isEmpty, carbs > 0 else { return }
            carbsStorage.storeRecentCarbPreset(RecentCarbPreset(name: note, carbs: carbs))
        }

        func presetLabel(_ preset: RecentCarbPreset) -> String {
            let amount = formatter.string(from: preset.carbs as NSNumber) ?? "0"
            return "\(preset.name) · \(amount) g"
        }
    }
}
