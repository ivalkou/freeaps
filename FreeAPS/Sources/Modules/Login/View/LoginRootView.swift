import SwiftUI

extension Login {
    struct RootView: BaseView {
        @EnvironmentObject var viewModel: ViewModel<Provider>

        var body: some View {
            VStack {
                Text("Disclaimer").font(.title)
                Spacer()
                Text(
                    "Disclaimer Description"
                )
                Spacer()
                Button(action: viewModel.login) {
                    Text("Agree and Continue")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .buttonBackground()
                }
            }.padding()
        }
    }
}
