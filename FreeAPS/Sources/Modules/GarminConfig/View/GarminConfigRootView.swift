import SwiftUI
import Swinject

#if !targetEnvironment(simulator)
    import ConnectIQ
#endif

extension GarminConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        var body: some View {
            Form {
                #if !targetEnvironment(simulator)
                    Section {
                        Button("Select devices") {
                            state.selectDevices()
                        }
                    }

                    if state.devices.isNotEmpty {
                        Section(header: Text("Connected devices")) {
                            ForEach(state.devices, id: \.uuid) { device in
                                Text(device.friendlyName)
                            }
                        }
                    }
                #else
                    Section {
                        Text("Garmin is not available in Simulator")
                            .foregroundColor(.secondary)
                    }
                #endif

                Section(header: Text("About")) {
                    Button("View sources on github.") {
                        UIApplication.shared.open(URL(string: "https://github.com/ivalkou/FreeAPSXGarmin")!)
                    }
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Garmin Watch")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
