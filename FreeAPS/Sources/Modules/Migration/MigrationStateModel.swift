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
            debug(.businessLogic, "Last migration did on version \(manager.lastMigrationAppVersion ?? "null")")
            Publishers
                .getMigrationPublisher(fromMigrationManager: manager)
//                 migration example
//                .migrate(onVersion: "0.2.5", MigrationWorkExample.run1)
//                .migrate(onVersion: "0.2.6", MigrationWorkExample.run2)
//                .migrate(onVersion: "0.2.7", MigrationWorkExample.run3)
                .updateLastAppMigrationVersionToCurrent()
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
