import SwiftUI
import Swinject

extension AppleHealthKit {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        var body: some View {
            Form {
                Section(
                    footer:
                    Text("FreeAPS X can write your blood glucose to Apple Health App")
                        .font(.caption)
                ) {
                    Toggle("Connect to Apple Health", isOn: $state.useAppleHealth)
                        .onChange(of: state.useAppleHealth) { _ in
                        }
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Apple Health")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
