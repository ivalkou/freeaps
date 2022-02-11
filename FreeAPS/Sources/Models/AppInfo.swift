import Foundation

protocol AppInfo {
    // curent target/app version
    var currentVersion: String { get }
}

class BaseAppInfo: AppInfo {
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    }
}
