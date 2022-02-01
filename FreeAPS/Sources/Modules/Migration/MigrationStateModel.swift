import SwiftMessages
import SwiftUI
import Swinject

extension Migration {
    final class StateModel: BaseStateModel<Provider> {
        @Published var animated: Bool = false
    }
}
