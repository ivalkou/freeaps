import Combine
import SwiftUI
import Swinject

extension Migration {
    @MainActor final class StateModel: BaseStateModel<Provider> {
        @Injected() private var manager: MigrationManager!

        @Published var animated: Bool = false
        @Published var loadingIsEnded: Bool = false

        func runMigration() {
            debug(.businessLogic, "Migration did start on current version \(manager.appInfo.currentVersion)")
            Publishers
                .getMigrationPublisher(fromMigrationManager: manager)
//                .migrate(startAtVersion: "0.2.6", MigrationWorkExample())
                .sink { _ in
                    debug(.businessLogic, "Migration did finish")
                    // fake pause
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.loadingIsEnded = true
                    }
                }
                .store(in: &lifetime)
        }
    }
}
