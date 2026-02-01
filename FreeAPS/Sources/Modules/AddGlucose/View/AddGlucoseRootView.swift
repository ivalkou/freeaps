import SwiftUI
import Swinject

extension AddGlucose {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if state.units == .mmolL {
                formatter.minimumFractionDigits = 1
                formatter.maximumFractionDigits = 1
            } else {
                formatter.maximumFractionDigits = 0
            }
            return formatter
        }

        var body: some View {
            Form {
                Section {
                    HStack {
                        Text("Glucose")
                        Spacer()
                        DecimalTextField(
                            "0",
                            value: $state.glucose,
                            formatter: formatter,
                            autofocus: true,
                            cleanInput: true
                        )
                        Text(state.units.rawValue).foregroundColor(.secondary)
                    }
                    DatePicker("Date", selection: $state.date)
                }

                Section {
                    Button { state.add() }
                    label: { Text("Add") }
                        .disabled(state.glucose <= 0)
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Add Glucose")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(leading: Button("Close", action: state.hideModal))
        }
    }
}
