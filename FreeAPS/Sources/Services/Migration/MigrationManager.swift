import Combine
import Foundation
import SwiftUI

class MigrationManager {
    private var needWorkAfterUpdateIntoVersion: [String] = []
    private var appInformation: TargetInformation
    var isNeedMigrate: Bool {
        return true
        guard !appInformation.isFirstExecute else {
            return false
        }
        guard let lastMigrationVersion = appInformation.lastMigrationVersion else {
            // if version < 0.2.6
            // in 0.2.6 was added MigrationManager
            return true
        }
        if !needWorkAfterUpdateIntoVersion.filter({ $0 > lastMigrationVersion }).isEmpty {
            // need execute handlers beetwen CurrentVersion...lastExecutedVersion, exclude lastExecutedVersion
            return true
        }
        return false
    }

    var publisher: AnyPublisher<TargetInformation, Never> {
        Publishers
            .getMigrationPublisher(appInformation)
            // example of migrating
            // .migrate(migrateExample)
            .actualLastMigrationVersion()
            .eraseToAnyPublisher()
    }

    init(appInformation: TargetInformation = TargetInformation()) {
        self.appInformation = appInformation
        // need execute one or more migration's handler after update into version 0.2.6
        // if need migrating on version 0.2.6, add
        // needWorkAfterUpdateIntoVersion.append("0.2.6")
    }

    private func checkNeedToRun(_ version: String) -> Bool {
        guard appInformation.currentVersion >= version,
              !appInformation.isFirstExecute
        else { return false }

        guard let lastMigrationVersion = appInformation.lastMigrationVersion,
              lastMigrationVersion == appInformation.currentVersion
        else { return true }
        return false
    }
}

// Migrating Example
extension MigrationManager {
    func migrateExample(_: TargetInformation) {
        guard checkNeedToRun("0.2.6") else { return }
        print("Sample migration handler")
    }
}
