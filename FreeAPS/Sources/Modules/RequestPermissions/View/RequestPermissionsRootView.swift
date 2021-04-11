import SwiftUI

extension RequestPermissions {
    struct RootView: BaseView {
        @EnvironmentObject var viewModel: ViewModel<Provider>

        var body: some View {
            Text(NSLocalizedString("RequestPermissions screen", comment: "RequestPermissions screen"))
                .navigationBarTitle(NSLocalizedString("RequestPermissions", comment: "RequestPermissions"))
                .navigationBarItems(leading: Button(NSLocalizedString("Close", comment: "Close"), action: viewModel.hideModal))
        }
    }
}
