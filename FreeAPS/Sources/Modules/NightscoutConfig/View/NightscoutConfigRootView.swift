import SwiftUI

extension NightscoutConfig {
    struct RootView: BaseView {
        @EnvironmentObject var viewModel: ViewModel<Provider>

        private var portFormater: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.allowsFloats = false
            return formatter
        }

        var body: some View {
            Form {
                Section {
                    TextField(NSLocalizedString("URL", comment: "URL"), text: $viewModel.url)
                        .disableAutocorrection(true)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    SecureField(NSLocalizedString("API secret", comment: "API secret"), text: $viewModel.secret)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .textContentType(.password)
                        .keyboardType(.asciiCapable)
                    if !viewModel.message.isEmpty {
                        Text(viewModel.message)
                    }
                    if viewModel.connecting {
                        HStack {
                            Text(NSLocalizedString("Connecting...", comment: "Connecting..."))
                            Spacer()
                            ProgressView()
                        }
                    }
                }

                Section {
                    Button(NSLocalizedString("Connect", comment: "Connect")) { viewModel.connect() }
                        .disabled(viewModel.url.isEmpty || viewModel.connecting)
                    Button(NSLocalizedString("Delete", comment: "Delete")) { viewModel.delete() }.foregroundColor(.red)
                        .disabled(viewModel.connecting)
                }

                Section {
                    Toggle(NSLocalizedString("Allow uploads", comment: "Allow uploads"), isOn: $viewModel.isUploadEnabled)
                }

                Section(header: Text(NSLocalizedString("Local glucose source", comment: "Local glucose source"))) {
                    Toggle(
                        NSLocalizedString("Use local glucose server", comment: "Use local glucose server"),
                        isOn: $viewModel.useLocalSource
                    )
                    HStack {
                        Text(NSLocalizedString("Port", comment: "Port"))
                        DecimalTextField("", value: $viewModel.localPort, formatter: portFormater)
                    }
                }
            }
            .navigationBarTitle(NSLocalizedString("Nightscout Config", comment: "Nightscout Config"), displayMode: .automatic)
        }
    }
}
