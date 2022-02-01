import Foundation

struct TargetInformation {
    @Persisted(key: "AppTargetInformation.lastMigrationVersion") private var _lastMigrationVersion: String = ""
    var lastMigrationVersion: String? {
        if _lastMigrationVersion == "" {
            // nil means that
            // 1) app run first time after install
            // or
            // 2) previous run was on version <= 0.2.6
            return nil
        }
        return _lastMigrationVersion
    }

    // App can be run first time
    var isFirstExecute: Bool {
        // check first app execution by preferences.json file
        // if file doesn't exist - the first execution
        Disk.exists(OpenAPS.Settings.preferences, in: .documents)
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    }

    mutating func actualLastMigrationVersion() {
        _lastMigrationVersion = currentVersion
    }
}
