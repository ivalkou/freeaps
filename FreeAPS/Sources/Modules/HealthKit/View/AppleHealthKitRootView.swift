import SwiftUI
import Swinject

extension AppleHealthKit {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        var body: some View {
            Form {
                Section {
                    Toggle("Connect to Apple Health", isOn: $state.useAppleHealth)
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                        Text(
                            "After you create records in the Health app, please open FreeAPS X to help us guaranteed transfer changed data"
                        )
                        .font(.caption)
                    }
                    .foregroundColor(Color.secondary)
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Apple Health")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
