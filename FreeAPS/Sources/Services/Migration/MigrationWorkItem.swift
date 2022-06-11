import Foundation

protocol MigrationWorkItem {
    // If true then migration will run each time while app is loading
    var repeatEachTime: Bool { get }
    // Unique identifier to store migration execute flag in UserDefaults
    var uniqueIdentifier: String { get }
    // Migration task
    func migrationHandler(_: AppInfo)
}

class MigrationWorkExample: MigrationWorkItem {
    private(set) var repeatEachTime: Bool = false
    private(set) var uniqueIdentifier: String = "Migration.MigrationWorkExample"
    func migrationHandler(_: AppInfo) {
        debug(.businessLogic, "Migration MigrationWorkExample will start")
    }
}
