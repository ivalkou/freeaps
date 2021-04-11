import SwiftUI

extension Login {
    struct RootView: BaseView {
        @EnvironmentObject var viewModel: ViewModel<Provider>

        var body: some View {
            VStack {
                Text(NSLocalizedString("Disclaimer", comment: "Disclaimer")).font(.title)
                Spacer()
                Text(
                    NSLocalizedString("Disclaimer Description", comment: "Disclaimer Description")
                )
                Spacer()
                Button(action: viewModel.login) {
                    Text(NSLocalizedString("Agree and Continue", comment: "Agree and continue"))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .buttonBackground()
                }
            }.padding()
        }
    }
}
