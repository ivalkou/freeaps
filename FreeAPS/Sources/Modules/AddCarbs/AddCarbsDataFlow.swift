enum AddCarbs {
    enum Config {}
}

protocol AddCarbsProvider: Provider {
    var suggestion: Suggestion? { get }
    func recentCarbPresets() -> [RecentCarbPreset]
    func deleteRecentCarbPreset(_ preset: RecentCarbPreset)
}
