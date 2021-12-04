import SwiftUI
import Swinject

extension AppleHealthKit {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        var body: some View {
            Form {
                Section {
                    Toggle(NSLocalizedString("Connect to Apple Health", comment: ""), isOn: $state.useAppleHealth)
                    if state.needShowInformationTextForSetPermissions {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(
                                NSLocalizedString(
                                    "For write data to Apple Health you must give permissions in Settings > Health > Data Access",
                                    comment: ""
                                )
                            )
                            .font(.caption)
                        }
                    }
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle(NSLocalizedString("Apple Health", comment: ""))
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
