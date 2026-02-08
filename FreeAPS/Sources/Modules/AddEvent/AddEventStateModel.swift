import SwiftUI

extension AddEvent {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var eventStorage: EventStorage!
        @Published var name: String = ""
        @Published var startDate = Date()
        @Published var endDate = Date()
        @Published var hasEndDate = false
        @Published var recentNames: [String] = []
        @Published var isEditingRecentNames = false

        var editingEvent: EventEntry?

        var isEditing: Bool { editingEvent != nil }

        override func subscribe() {
            recentNames = provider.recentEventNames().sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            if let event = editingEvent {
                name = event.name
                startDate = event.createdAt
                if let end = event.endAt {
                    hasEndDate = true
                    endDate = end
                }
            }
        }

        func save() {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                showModal(for: nil)
                return
            }

            let end: Date? = hasEndDate ? endDate : nil

            if let existing = editingEvent {
                let updated = EventEntry(
                    id: existing.id,
                    name: trimmedName,
                    createdAt: startDate,
                    endAt: end
                )
                eventStorage.updateEvent(updated)
            } else {
                let entry = EventEntry(
                    name: trimmedName,
                    createdAt: startDate,
                    endAt: end
                )
                eventStorage.storeEvents([entry])
            }

            showModal(for: nil)
        }

        func selectRecentName(_ recentName: String) {
            name = recentName
        }

        func deleteRecentName(_ recentName: String) {
            provider.deleteRecentEventName(recentName)
            recentNames.removeAll { $0 == recentName }
            if name == recentName {
                name = ""
            }
        }
    }
}
