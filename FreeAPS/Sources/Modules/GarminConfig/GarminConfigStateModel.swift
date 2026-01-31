import SwiftUI

#if !targetEnvironment(simulator)
    import ConnectIQ
#endif

extension GarminConfig {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() private var garmin: GarminManager!

        #if !targetEnvironment(simulator)
            @Published var devices: [IQDevice] = []
        #else
            @Published var devices: [Any] = []
        #endif

        override func subscribe() {
            devices = garmin.devices
        }

        func selectDevices() {
            garmin.selectDevices()
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.devices, on: self)
                .store(in: &lifetime)
        }
    }
}
