import SwiftUI

extension AutotuneConfig {
    struct RootView: BaseView {
        @EnvironmentObject var viewModel: ViewModel<Provider>

        private var isfFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        private var rateFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 3
            return formatter
        }

        var body: some View {
            Form {
                Section {
                    Toggle(NSLocalizedString("use Autotune", comment: "Use Autotune"), isOn: $viewModel.useAutotune)
                }

                Section {
                    Button { viewModel.run() }
                    label: { Text(NSLocalizedString("Run now", comment: "Run now")) }
                }

                if let autotune = viewModel.autotune {
                    Section {
                        HStack {
                            Text(NSLocalizedString("Carb ratio", comment: "Carb ratio"))
                            Spacer()
                            Text(isfFormatter.string(from: autotune.carbRatio as NSNumber) ?? "0")
                            Text("g/U").foregroundColor(.secondary)
                        }
                        HStack {
                            Text(NSLocalizedString("Sensitivity", comment: "Sensitivity"))
                            Spacer()
                            if viewModel.units == .mmolL {
                                Text(isfFormatter.string(from: autotune.sensitivity.asMmolL as NSNumber) ?? "0")
                            } else {
                                Text(isfFormatter.string(from: autotune.sensitivity as NSNumber) ?? "0")
                            }
                            Text(viewModel.units.rawValue + "/U").foregroundColor(.secondary)
                        }
                    }

                    Section(header: Text(NSLocalizedString("Basal profile", comment: "Basal profile"))) {
                        ForEach(0 ..< autotune.basalProfile.count, id: \.self) { index in
                            HStack {
                                Text(autotune.basalProfile[index].start).foregroundColor(.secondary)
                                Spacer()
                                Text(rateFormatter.string(from: autotune.basalProfile[index].rate as NSNumber) ?? "0")
                                Text("U/hr").foregroundColor(.secondary)
                            }
                        }
                    }

                    Section {
                        Button { viewModel.delete() }
                        label: { Text(NSLocalizedString("Delete autotune data", comment: "Delete autotune data")) }
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Autotune", comment: "Autotune Title"))
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
