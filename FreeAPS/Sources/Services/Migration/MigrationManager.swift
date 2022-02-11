import Combine
import Foundation
import SwiftUI
import Swinject

protocol MigrationManager {
    var appInfo: AppInfo { get }
    // 'true' when app run first time
    var isFirstExecute: Bool { get }
    // last version of app/target, which did execute
    var lastMigrationAppVersion: String? { get }
    // update 'lastExecutedVersion' to 'currentVersion'
    func setActualLastMigrationAppVersion()

    func checkMigrationNeeded(onVersion version: String) -> Bool

    init(resolver: Resolver)
}

class BaseMigrationManager: MigrationManager {
    @Persisted(key: "AppInfo.lastMigrationAppVersion") private var _lastMigrationAppVersion: String = ""
    var lastMigrationAppVersion: String? {
        if _lastMigrationAppVersion == "" {
            // nil means that
            // 1) app execute first time after install on version >= 0.2.6
            // or
            // 2) previous execution was on version <= 0.2.6
            return nil
        }
        return _lastMigrationAppVersion
    }

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

    func checkMigrationNeeded(onVersion version: String) -> Bool {
        guard appInfo.currentVersion >= version else { return false }
        guard !isFirstExecute else { return false }
        guard let last = lastMigrationAppVersion else { return true }
        guard last < version else { return false }
        return true
    }

    func setActualLastMigrationAppVersion() {
        _lastMigrationAppVersion = appInfo.currentVersion
    }
}
