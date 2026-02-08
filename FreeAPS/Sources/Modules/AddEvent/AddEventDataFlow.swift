enum AddEvent {
    enum Config {}
}

protocol AddEventProvider: Provider {
    func recentEventNames() -> [String]
    func deleteRecentEventName(_ name: String)
}
