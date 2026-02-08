extension AddEvent {
    final class Provider: BaseProvider, AddEventProvider {
        @Injected() var eventStorage: EventStorage!

        func recentEventNames() -> [String] {
            eventStorage.recentEventNames()
        }

        func deleteRecentEventName(_ name: String) {
            eventStorage.deleteRecentEventName(name)
        }
    }
}
