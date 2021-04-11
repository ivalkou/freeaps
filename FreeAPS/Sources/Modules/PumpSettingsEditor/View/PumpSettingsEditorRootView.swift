import SwiftUI

extension PumpSettingsEditor {
    struct RootView: BaseView {
        @EnvironmentObject var viewModel: ViewModel<Provider>

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter
        }

        var body: some View {
            Form {
                Section(header: Text(NSLocalizedString("Delivery limits", comment: "Delivery limits"))) {
                    HStack {
                        Text(NSLocalizedString("Max Basal", comment: "Max Basal"))
                        DecimalTextField(
                            NSLocalizedString("hours", comment: "hours"),
                            value: $viewModel.maxBasal,
                            formatter: formatter
                        )
                    }
                    HStack {
                        Text(NSLocalizedString("Max Bolus", comment: "Max Bolus"))
                        DecimalTextField(
                            NSLocalizedString("U/hr", comment: "U/hr"),
                            value: $viewModel.maxBolus,
                            formatter: formatter
                        )
                    }
                }

                Section(header: Text(NSLocalizedString("Duration of Insulin Action", comment: "Duration of Insulin Action"))) {
                    HStack {
                        Text("DIA")
                        DecimalTextField("hours", value: $viewModel.dia, formatter: formatter)
                    }
                }

                Section {
                    HStack {
                        if viewModel.syncInProgress {
                            ProgressView().padding(.trailing, 10)
                        }
                        Button { viewModel.save() }
                        label: {
                            Text(
                                viewModel
                                    .syncInProgress ? NSLocalizedString("Saving...", comment: "Saving...") :
                                    NSLocalizedString("Save on Pump", comment: "Save on Pump")
                            )
                        }
                        .disabled(viewModel.syncInProgress)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Pump Settings", comment: "Pump Settings"))
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
