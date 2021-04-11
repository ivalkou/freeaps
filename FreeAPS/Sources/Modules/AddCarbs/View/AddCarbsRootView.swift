import SwiftUI

extension AddCarbs {
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
                        Text(NSLocalizedString("Amount Carbs", comment: "Amount Carbs"))
                        Spacer()
                        DecimalTextField("0", value: $viewModel.carbs, formatter: formatter, autofocus: true, cleanInput: true)
                        Text(NSLocalizedString("grams", comment: "Grams unit")).foregroundColor(.secondary)
                    }
                    DatePicker(NSLocalizedString("Date", comment: "Date"), selection: $viewModel.date)
                }

                Section {
                    Button { viewModel.add() }
                    label: { Text(NSLocalizedString("Add Carbs", comment: "Add Carbs")) }
                }
            }
            .navigationTitle(NSLocalizedString("Add Carbs Title", comment: "Add Carbs Title"))
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(leading: Button(NSLocalizedString("Close", comment: "Close"), action: viewModel.hideModal))
        }
    }
}
