import Combine
import Foundation
import SwiftUI
import Swinject

protocol MigrationManager {
    var appInfo: AppInfo { get }
    // 'true' when app run first time
    var isFirstExecute: Bool { get }

    func checkMigrationNeededRun(_: MigrationWorkItem, startAtVersion version: String) -> Bool

    init(resolver: Resolver)
}

class BaseMigrationManager: MigrationManager {
    var isFirstExecute: Bool {
        // check first app execution by preferences.json file
        // if file doesn't exist - the first execution
        !Disk.exists(OpenAPS.FreeAPS.settings, in: .documents)
    }

    var appInfo: AppInfo

    private var resolver: Resolver

    required init(resolver: Resolver) {
        self.resolver = resolver
        appInfo = resolver.resolve(AppInfo.self)!
    }

    func checkMigrationNeededRun(_ migrationWorkItem: MigrationWorkItem, startAtVersion version: String) -> Bool {
        // if current app version >= version of migration needed
        guard appInfo.currentVersion >= version else { return false }
        // if migration need to run each app execution
        if migrationWorkItem.repeatEachTime { return true }
        // if it first run of app
        guard !isFirstExecute else { return false }
        // if migration did run in past
        guard UserDefaults.standard.optionalBool(forKey: migrationWorkItem.uniqueIdentifier) == nil else { return false }
        return true
    }
}
