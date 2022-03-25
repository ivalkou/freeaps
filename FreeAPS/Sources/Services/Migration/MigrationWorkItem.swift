//
// This file contains WorkItems with migration tasks
// Each WorkItem have to execute one migration task
// Each WorkItem can be run in Migration.StateModel.runMigration()
//  ...
//  .migrate(startAtVersion: "0.2.6", MigrationWorkExample())
//  ...

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
