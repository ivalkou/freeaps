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

// MARK: - Migration carbs at 0.2.6

// New CarbsEntry class (with new id property) was create.
// This work item add new property to carbs in carbs.json

class MigrationCarbs: MigrationWorkItem {
    private(set) var repeatEachTime: Bool = false
    private(set) var uniqueIdentifier: String = "Migration.MigrationCarbs"
    func migrationHandler(_: AppInfo) {
        let resolver = FreeAPSApp.resolver
        let fileStorage = resolver.resolve(FileStorage.self)!
        let carbsStorage = resolver.resolve(CarbsStorage.self)!
        guard let oldCarbs = fileStorage.retrieve(OpenAPS.Monitor.carbHistory, as: [CarbsEntryTill026].self) else { return }
        carbsStorage.storeCarbs(convert(carbs: oldCarbs))
    }

    private func convert(carbs: [CarbsEntryTill026]) -> [CarbsEntry] {
        carbs.map { oldCarb in
            CarbsEntry(createdAt: oldCarb.createdAt, carbs: oldCarb.carbs, enteredBy: oldCarb.enteredBy)
        }
    }
}
