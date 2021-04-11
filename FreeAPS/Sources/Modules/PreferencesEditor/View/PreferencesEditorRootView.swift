import SwiftUI

extension PreferencesEditor {
    struct RootView: BaseView {
        @EnvironmentObject var viewModel: ViewModel<Provider>

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter
        }

        var body: some View {
            Form {
                Section(header: Text("FreeAPS X")) {
                    Picker(NSLocalizedString("Glucose units", comment: "Glucose units"), selection: $viewModel.unitsIndex) {
                        Text("mg/dL").tag(0)
                        Text("mmol/L").tag(1)
                    }

                    Toggle(NSLocalizedString("Remote control", comment: "Remote control"), isOn: $viewModel.allowAnnouncements)

                    HStack {
                        Text(NSLocalizedString("Recommended Insulin Fraction", comment: "Recommended Insulin Fraction"))
                        DecimalTextField("", value: $viewModel.insulinReqFraction, formatter: formatter)
                    }
                }

                Section(header: Text("OpenAPS")) {
                    Picker(selection: $viewModel.insulinCurveField.value, label: Text(viewModel.insulinCurveField.displayName)) {
                        ForEach(InsulinCurve.allCases) { v in
                            Text(v.rawValue).tag(v)
                        }
                    }

                    ForEach(viewModel.boolFields.indexed(), id: \.1.id) { index, field in
                        Toggle(field.displayName, isOn: self.$viewModel.boolFields[index].value)
                    }

                    ForEach(viewModel.decimalFields.indexed(), id: \.1.id) { index, field in
                        HStack {
                            Text(field.displayName)
                            DecimalTextField("0", value: self.$viewModel.decimalFields[index].value, formatter: formatter)
                        }
                    }
                }

                Section {
                    Text(NSLocalizedString("Edit settings json", comment: "Edit settings json")).chevronCell()
                        .navigationLink(to: .configEditor(file: OpenAPS.FreeAPS.settings), from: self)
                }
            }
            .navigationTitle(NSLocalizedString("Preferences", comment: "Preferences"))
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
