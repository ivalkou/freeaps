import Foundation
import SwiftDate
import Swinject

protocol GlucoseStorage {
    func storeGlucose(_ glucose: [BloodGlucose])
    func removeGlucose(byID id: String)
    func removeGlucose(byIDCollection ids: [String])
    func recent() -> [BloodGlucose]
    func syncDate() -> Date
    func filterTooFrequentGlucose(_ glucose: [BloodGlucose], at: Date) -> [BloodGlucose]
    func lastGlucoseDate() -> Date
    func isGlucoseFresh() -> Bool
    func isGlucoseNotFlat() -> Bool
    func nightscoutGlucoseNotUploaded() -> [BloodGlucose]
    var alarm: GlucoseAlarm? { get }
}

final class BaseGlucoseStorage: GlucoseStorage, Injectable {
    private let processQueue = DispatchQueue(label: "BaseGlucoseStorage.processQueue")
    @Injected() private var storage: FileStorage!
    @Injected() private var broadcaster: Broadcaster!
    @Injected() private var settingsManager: SettingsManager!

    private enum Config {
        static let filterTime: TimeInterval = 4.5 * 60
    }

    init(resolver: Resolver) {
        injectServices(resolver)
    }

    func storeGlucose(_ glucose: [BloodGlucose]) {
        processQueue.sync {
            let file = OpenAPS.Monitor.glucose
            self.storage.transaction { storage in
                storage.append(glucose, to: file, uniqBy: \.dateString)
                let uniqEvents = storage.retrieve(file, as: [BloodGlucose].self)?
                    .filter { $0.dateString.addingTimeInterval(1.days.timeInterval) > Date() }
                    .sorted { $0.dateString > $1.dateString } ?? []
                let glucose = Array(uniqEvents)
                storage.save(glucose, as: file)

                DispatchQueue.main.async {
                    self.broadcaster.notify(GlucoseObserver.self, on: .main) {
                        $0.glucoseDidUpdate(glucose.reversed())
                    }
                }
            }
        }
    }

    func removeGlucose(byIDCollection ids: [String]) {
        processQueue.sync {
            let file = OpenAPS.Monitor.glucose
            self.storage.transaction { storage in
                let bgInStorage = storage.retrieve(file, as: [BloodGlucose].self)
                let filteredBG = bgInStorage?.filter { !ids.contains($0.id) } ?? []
                storage.save(filteredBG, as: file)

                DispatchQueue.main.async {
                    self.broadcaster.notify(GlucoseObserver.self, on: .main) {
                        $0.glucoseDidUpdate(filteredBG.reversed())
                    }
                }
            }
        }
    }

    func removeGlucose(byID id: String) {
        processQueue.sync {
            let file = OpenAPS.Monitor.glucose
            self.storage.transaction { storage in
                let bgInStorage = storage.retrieve(file, as: [BloodGlucose].self)
                let filteredBG = bgInStorage?.filter { $0.id != id } ?? []
                storage.save(filteredBG, as: file)

                DispatchQueue.main.async {
                    self.broadcaster.notify(GlucoseObserver.self, on: .main) {
                        $0.glucoseDidUpdate(filteredBG.reversed())
                    }
                }
            }
        }
    }

    func syncDate() -> Date {
        guard let events = storage.retrieve(OpenAPS.Monitor.glucose, as: [BloodGlucose].self),
              let recent = events.first
        else {
            return Date().addingTimeInterval(-1.days.timeInterval)
        }
        return recent.dateString
    }

    func recent() -> [BloodGlucose] {
        storage.retrieve(OpenAPS.Monitor.glucose, as: [BloodGlucose].self)?.reversed() ?? []
    }

    func lastGlucoseDate() -> Date {
        recent().last?.dateString ?? .distantPast
    }

    func isGlucoseFresh() -> Bool {
        Date().timeIntervalSince(lastGlucoseDate()) <= Config.filterTime
    }

    func filterTooFrequentGlucose(_ glucose: [BloodGlucose], at date: Date) -> [BloodGlucose] {
        var lastDate = date
        var filtered: [BloodGlucose] = []

        for entry in glucose.reversed() {
            guard entry.dateString.addingTimeInterval(-Config.filterTime) > lastDate else {
                continue
            }
            filtered.append(entry)
            lastDate = entry.dateString
        }

        return filtered
    }

    func isGlucoseNotFlat() -> Bool {
        let last3 = recent().suffix(3)
        guard last3.count == 3 else { return true }

        return Array(
            last3
                .compactMap { $0.filtered ?? 0 }
                .filter { $0 != 0 }
                .uniqued()
        ).count != 1
    }

    func nightscoutGlucoseNotUploaded() -> [BloodGlucose] {
        let uploaded = storage.retrieve(OpenAPS.Nightscout.uploadedGlucose, as: [BloodGlucose].self) ?? []
        let recentGlucose = recent()

        return Array(Set(recentGlucose).subtracting(Set(uploaded)))
    }

    var alarm: GlucoseAlarm? {
        guard let glucose = recent().last, glucose.dateString.addingTimeInterval(20.minutes.timeInterval) > Date(),
              let glucoseValue = glucose.glucose else { return nil }

        if Decimal(glucoseValue) < settingsManager.settings.lowGlucose {
            return .low
        }

        if Decimal(glucoseValue) > settingsManager.settings.highGlucose {
            return .high
        }

        return nil
    }
}

protocol GlucoseObserver {
    func glucoseDidUpdate(_ glucose: [BloodGlucose])
}

enum GlucoseAlarm {
    case high
    case low

    var displayName: String {
        switch self {
        case .high:
            return NSLocalizedString("LOWALERT!", comment: "LOWALERT!")
        case .low:
            return NSLocalizedString("HIGHALERT!", comment: "HIGHALERT!")
        }
    }
}
