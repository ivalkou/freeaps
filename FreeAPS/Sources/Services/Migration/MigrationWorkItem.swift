import Foundation

protocol MigrationWorkItem {}

class MigrationWorkExample: MigrationWorkItem {
    static func run1(appInfo _: AppInfo) {
        // add here any migration logic
        print("did some migration work on 0.2.5")
    }

    static func run2(appInfo _: AppInfo) {
        // add here any migration logic
        print("did some migration work on 0.2.6")
    }

    static func run3(appInfo _: AppInfo) {
        // add here any migration logic
        print("did some migration work on 0.2.7")
    }
}
