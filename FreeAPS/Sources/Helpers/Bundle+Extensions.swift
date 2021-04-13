import Foundation

public extension Bundle {
    var appGroupSuiteName: String? {
        object(forInfoDictionaryKey: "AppGroupID") as? String
    }
}

extension UserDefaults {
    static var appGroup: UserDefaults? {
        guard let suiteName = Bundle.main.appGroupSuiteName else {
            return nil
        }
        return UserDefaults(suiteName: suiteName)
    }
}
