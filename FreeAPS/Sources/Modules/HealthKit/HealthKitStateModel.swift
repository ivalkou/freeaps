import Combine
import SwiftUI

extension AppleHealthKit {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var healthKitManager: HealthKitManager!

        @Published var useAppleHealth = false

        override func subscribe() {
            useAppleHealth = settingsManager.settings.useAppleHealth

            subscribeSetting(\.useAppleHealth, on: $useAppleHealth) {
                useAppleHealth = $0
            } didSet: { [weak self] value in
                guard let self = self else { return }

                guard value else { return }

                self.healthKitManager.requestPermission { ok, error in

                    guard ok, error == nil else {
                        warning(.service, "Permission not granted for HealthKitManager", error: error)
                        return
                    }

                    debug(.service, "Permission  granted HealthKitManager")

                    self.healthKitManager.configureManager()
                }
            }
        }
    }
}
