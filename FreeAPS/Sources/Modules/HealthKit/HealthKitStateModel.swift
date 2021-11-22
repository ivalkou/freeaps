import Combine
import SwiftUI

extension AppleHealthKit {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var settingsManager: SettingsManager!
        var healthKitManager: HealthKitManager!

        @Published var useAppleHealth = false

        @Injected() var libreSource: LibreTransmitterSource!
        @Injected() var calendarManager: CalendarManager!

        @Published var cgm: CGMType = .nightscout
        @Published var transmitterID = ""
        @Published var uploadGlucose = false
        @Published var createCalendarEvents = false
        @Published var calendarIDs: [String] = []
        @Published var currentCalendarID: String = ""
        @Persisted(key: "CalendarManager.currentCalendarID") var storedCalendarID: String? = nil

        override func subscribe() {
            healthKitManager = BaseHealthKitManager()
            useAppleHealth = settingsManager.settings.useAppleHealth

            $useAppleHealth
                .removeDuplicates()
                .sink { [weak self] value in
                    guard let self = self else { return }
                    
                    self.healthKitManager.checkRequestPermissionStatus { result in
                        switch result {
                        case .success(let status) where status == .needRequest:
                            self.healthKitManager.requestPermission(completion: nil)
                        case .success(let status) where status == .didRequest:
                            return
                        default:
                            return
                        }
                    }
                    // self.healthKitManager.requestPermission()
                    self.settingsManager.settings.useAppleHealth = value
                }
                .store(in: &lifetime)
        }
    }
}
