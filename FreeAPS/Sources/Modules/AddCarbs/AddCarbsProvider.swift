extension AddCarbs {
    final class Provider: BaseProvider, AddCarbsProvider {
        @Injected() var carbsStorage: CarbsStorage!

        var suggestion: Suggestion? {
            storage.retrieve(OpenAPS.Enact.suggested, as: Suggestion.self)
        }

        func recentCarbPresets() -> [RecentCarbPreset] {
            carbsStorage.recentCarbPresets()
        }

        func deleteRecentCarbPreset(_ preset: RecentCarbPreset) {
            carbsStorage.deleteRecentCarbPreset(preset)
        }
    }
}
