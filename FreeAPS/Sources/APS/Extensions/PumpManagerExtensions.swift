import LoopKit
import LoopKitUI

extension PumpManager {
    var rawValue: [String: Any] {
        [
            "managerIdentifier": managerIdentifier, // "managerIdentifier": type(of: self).managerIdentifier,
            "state": rawState
        ]
    }
}

extension PumpManagerUI {
//    static func setupViewController() -> PumpManagerSetupViewController & UIViewController & CompletionNotifying {
//        setupViewController(
//            insulinTintColor: .accentColor,
//            guidanceColors: GuidanceColors(acceptable: .green, warning: .orange, critical: .red),
//            allowedInsulinTypes: [.apidra, .humalog, .novolog, .fiasp, .lyumjev]
//        )
//    }

    func settingsViewController(bluetoothProvider: BluetoothProvider) -> UIViewController & CompletionNotifying {
        settingsViewController(
            bluetoothProvider: bluetoothProvider,
            colorPalette: .default,
            allowDebugFeatures: false,
            allowedInsulinTypes: [.apidra, .humalog, .novolog, .fiasp, .lyumjev]
        )
    }

//    func settingsViewController() -> UIViewController & CompletionNotifying {
//        settingsViewController(
//            insulinTintColor: .accentColor,
//            guidanceColors: GuidanceColors(acceptable: .green, warning: .orange, critical: .red),
//            allowedInsulinTypes: [.apidra, .humalog, .novolog, .fiasp, .lyumjev]
//        )
//    }
}

protocol PumpSettingsBuilder {
    func settingsViewController() -> UIViewController & CompletionNotifying
}
