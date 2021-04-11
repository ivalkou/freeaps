import SwiftUI

extension Bolus {
    struct RootView: BaseView {
        @EnvironmentObject var viewModel: ViewModel<Provider>

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        var body: some View {
            Form {
                Section(header: Text(NSLocalizedString("Recommandation", comment: "StringRecommendation"))) {
                    if viewModel.waitForSuggestion {
                        HStack {
                            Text(NSLocalizedString("Wait please", comment: "Wait please")).foregroundColor(.secondary)
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        HStack {
                            Text(NSLocalizedString("Insulin required", comment: "Insulin required")).foregroundColor(.secondary)
                            Spacer()
                            Text(formatter.string(from: viewModel.inslinRequired as NSNumber)! + " U").foregroundColor(.secondary)
                        }.contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.amount = viewModel.inslinRecommended
                            }
                        HStack {
                            Text(NSLocalizedString("Insulin recommanded", comment: "Insulin recommended"))
                            Spacer()
                            Text(formatter.string(from: viewModel.inslinRecommended as NSNumber)! + " U")
                        }.contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.amount = viewModel.inslinRecommended
                            }
                    }
                }

                if !viewModel.waitForSuggestion {
                    Section(header: Text(NSLocalizedString("Bolus", comment: "Bolus"))) {
                        HStack {
                            Text(NSLocalizedString("Amount Bolus", comment: "Amount"))
                            Spacer()
                            DecimalTextField(
                                "0",
                                value: $viewModel.amount,
                                formatter: formatter,
                                autofocus: true,
                                cleanInput: true
                            )
                            Text("U").foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Button { viewModel.add() }
                        label: { Text(NSLocalizedString("Enact bolus", comment: "Enact Bolus")) }

                        if viewModel.waitForSuggestionInitial {
                            Button { viewModel.showModal(for: nil) }
                            label: { Text(NSLocalizedString("Continue without bolus", comment: "Continue without bolus")) }
                        } else {
                            Button { viewModel.addWithoutBolus() }
                            label: {
                                Text(NSLocalizedString(
                                    "Add insulin without actually bolusing",
                                    comment: "Add insulin without actually bolusing"
                                )) }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Enact Bolus Titre", comment: "Enact Bolus title"))
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(leading: Button(NSLocalizedString("Close", comment: "Close"), action: viewModel.hideModal))
        }
    }
}
