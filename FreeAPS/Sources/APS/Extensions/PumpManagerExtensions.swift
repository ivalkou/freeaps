import LoopKit
import LoopKitUI

extension PumpManager {
    var rawValue: [String: Any] {
        [
            "managerIdentifier": type(of: self).managerIdentifier,
            "state": rawState
        ]
    }
}

extension PumpManagerUI {
    static func setupViewController() -> PumpManagerSetupViewController & UIViewController & CompletionNotifying {
        setupViewController()
    }

    func settingsViewController() -> UIViewController & CompletionNotifying {
        settingsViewController()
    }
}

protocol PumpSettingsBuilder {
    func settingsViewController() -> UIViewController & CompletionNotifying
}
