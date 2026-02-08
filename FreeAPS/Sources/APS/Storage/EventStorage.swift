import Foundation
import SwiftDate
import Swinject

protocol EventsObserver {
    func eventsDidUpdate(_ events: [EventEntry])
}

protocol EventStorage {
    func storeEvents(_ events: [EventEntry])
    func recent() -> [EventEntry]
    func deleteEvent(id: String)
    func updateEvent(_ event: EventEntry)
    func recentEventNames() -> [String]
    func storeRecentEventName(_ name: String)
    func deleteRecentEventName(_ name: String)
}

final class BaseEventStorage: EventStorage, Injectable {
    private let processQueue = DispatchQueue(label: "BaseEventStorage.processQueue")
    @Injected() private var storage: FileStorage!
    @Injected() private var broadcaster: Broadcaster!

    init(resolver: Resolver) {
        injectServices(resolver)
    }

    func storeEvents(_ events: [EventEntry]) {
        processQueue.sync {
            let file = OpenAPS.FreeAPS.events
            var uniqEvents: [EventEntry] = []
            self.storage.transaction { storage in
                storage.append(events, to: file, uniqBy: \.id)
                uniqEvents = storage.retrieve(file, as: [EventEntry].self)?
                    .filter { $0.createdAt.addingTimeInterval(1.days.timeInterval) > Date() }
                    .sorted { $0.createdAt > $1.createdAt } ?? []
                storage.save(Array(uniqEvents), as: file)
            }
            for event in events {
                storeRecentEventName(event.name)
            }
            broadcaster.notify(EventsObserver.self, on: processQueue) {
                $0.eventsDidUpdate(uniqEvents)
            }
        }
    }

    func recent() -> [EventEntry] {
        storage.retrieve(OpenAPS.FreeAPS.events, as: [EventEntry].self)?
            .filter { $0.createdAt.addingTimeInterval(1.days.timeInterval) > Date() }
            .sorted { $0.createdAt > $1.createdAt } ?? []
    }

    func deleteEvent(id: String) {
        processQueue.sync {
            let file = OpenAPS.FreeAPS.events
            var allValues = storage.retrieve(file, as: [EventEntry].self) ?? []
            guard let entryIndex = allValues.firstIndex(where: { $0.id == id }) else {
                return
            }
            allValues.remove(at: entryIndex)
            storage.save(allValues, as: file)
            broadcaster.notify(EventsObserver.self, on: processQueue) {
                $0.eventsDidUpdate(allValues)
            }
        }
    }

    func updateEvent(_ event: EventEntry) {
        processQueue.sync {
            let file = OpenAPS.FreeAPS.events
            var allValues = storage.retrieve(file, as: [EventEntry].self) ?? []
            guard let entryIndex = allValues.firstIndex(where: { $0.id == event.id }) else {
                return
            }
            allValues[entryIndex] = event
            storage.save(allValues, as: file)
            storeRecentEventName(event.name)
            broadcaster.notify(EventsObserver.self, on: processQueue) {
                $0.eventsDidUpdate(allValues)
            }
        }
    }

    func recentEventNames() -> [String] {
        storage.retrieve(OpenAPS.FreeAPS.recentEventNames, as: [String].self) ?? []
    }

    func storeRecentEventName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var names = recentEventNames()
        names.removeAll { $0 == trimmed }
        names.insert(trimmed, at: 0)
        if names.count > 20 {
            names = Array(names.prefix(20))
        }
        storage.save(names, as: OpenAPS.FreeAPS.recentEventNames)
    }

    func deleteRecentEventName(_ name: String) {
        var names = recentEventNames()
        names.removeAll { $0 == name }
        storage.save(names, as: OpenAPS.FreeAPS.recentEventNames)
    }
}
