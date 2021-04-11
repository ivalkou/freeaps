import SwiftUI

extension PumpConfig {
    struct RootView: BaseView {
        @EnvironmentObject var viewModel: ViewModel<Provider>

        var body: some View {
            Form {
                Section(header: Text(NSLocalizedString("Model", comment: "Model"))) {
                    if let pumpState = viewModel.pumpState {
                        Button {
                            viewModel.setupPump = true
                        } label: {
                            HStack {
                                Image(uiImage: pumpState.image ?? UIImage()).padding()
                                Text(pumpState.name)
                            }
                        }
                    } else {
                        Button(NSLocalizedString("Add Medtronic", comment: "Add Medtronic")) { viewModel.addPump(.minimed) }
                        Button(NSLocalizedString("Add Omnipod", comment: "Add Omnipod")) { viewModel.addPump(.omnipod) }
                        Button(NSLocalizedString("Add Simulator", comment: "Add Simulator")) { viewModel.addPump(.simulator) }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Pump config", comment: "Pump config"))
            .navigationBarTitleDisplayMode(.automatic)
            .popover(isPresented: $viewModel.setupPump) {
                if let pumpManager = viewModel.provider.apsManager.pumpManager {
                    PumpSettingsView(pumpManager: pumpManager, completionDelegate: viewModel)
                } else {
                    PumpSetupView(
                        pumpType: viewModel.setupPumpType,
                        pumpInitialSettings: viewModel.initialSettings,
                        completionDelegate: viewModel,
                        setupDelegate: viewModel
                    )
                }
            }
        }
    }
}
