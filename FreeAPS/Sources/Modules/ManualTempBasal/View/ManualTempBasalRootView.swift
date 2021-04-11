import SwiftUI

extension ManualTempBasal {
    struct RootView: BaseView {
        @EnvironmentObject var viewModel: ViewModel<Provider>

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }

        var body: some View {
            Form {
                Section {
                    HStack {
                        Text(NSLocalizedString("Amount", comment: "Amount"))
                        Spacer()
                        DecimalTextField("0", value: $viewModel.rate, formatter: formatter, autofocus: true, cleanInput: true)
                        Text("U/hr").foregroundColor(.secondary)
                    }
                    Picker(selection: $viewModel.durationIndex, label: Text(NSLocalizedString("Duration", comment: "Duration"))) {
                        ForEach(0 ..< viewModel.durationValues.count) { index in
                            Text(
                                String(
                                    format: "%.0f h %02.0f min",
                                    viewModel.durationValues[index] / 60 - 0.1,
                                    viewModel.durationValues[index].truncatingRemainder(dividingBy: 60)
                                )
                            ).tag(index)
                        }
                    }
                }

                Section {
                    Button { viewModel.enact() }
                    label: { Text(NSLocalizedString("Enact", comment: "Enact")) }
                    Button { viewModel.cancel() }
                    label: { Text(NSLocalizedString("Cancel Temp Basal", comment: "Cancel Temp Basal")) }
                }
            }
            .navigationTitle(NSLocalizedString("Manual Temp Basal", comment: "Manual Temp Basal"))
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(leading: Button(NSLocalizedString("Close", comment: "Close"), action: viewModel.hideModal))
        }
    }
}
