//
//  MinimedPumpManager+UI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import MinimedKit


extension MinimedPumpManager: PumpManagerUI {

    static public func setupViewController() -> (UIViewController & PumpManagerSetupViewController & CompletionNotifying) {
        return MinimedPumpManagerSetupViewController.instantiateFromStoryboard()
    }

    public func settingsViewController() -> (UIViewController & CompletionNotifying) {
        let settings = MinimedPumpSettingsViewController(pumpManager: self)
        let nav = SettingsNavigationViewController(rootViewController: settings)
        return nav
    }

    public var smallImage: UIImage? {
        return state.smallPumpImage
    }
    
    public func hudProvider() -> HUDProvider? {
        return MinimedHUDProvider(pumpManager: self)
    }
    
    public static func createHUDViews(rawValue: HUDProvider.HUDViewsRawState) -> [BaseHUDView] {
        return MinimedHUDProvider.createHUDViews(rawValue: rawValue)
    }
}

// MARK: - DeliveryLimitSettingsTableViewControllerSyncSource
extension MinimedPumpManager {
    public func syncDeliveryLimitSettings(for viewController: DeliveryLimitSettingsTableViewController, completion: @escaping (DeliveryLimitSettingsResult) -> Void) {
        pumpOps.runSession(withName: "Save Settings", using: rileyLinkDeviceProvider.firstConnectedDevice) { (session) in
            guard let session = session else {
                completion(.failure(PumpManagerError.connection(MinimedPumpManagerError.noRileyLink)))
                return
            }

            do {
                if let maxBasalRate = viewController.maximumBasalRatePerHour {
                    try session.setMaxBasalRate(unitsPerHour: maxBasalRate)
                }

                if let maxBolus = viewController.maximumBolus {
                    try session.setMaxBolus(units: maxBolus)
                }

                let settings = try session.getSettings()
                completion(.success(maximumBasalRatePerHour: settings.maxBasal, maximumBolus: settings.maxBolus))
            } catch let error {
                self.log.error("Save delivery limit settings failed: %{public}@", String(describing: error))
                completion(.failure(error))
            }
        }
    }

    public func syncButtonTitle(for viewController: DeliveryLimitSettingsTableViewController) -> String {
        return LocalizedString("Save to Pump…", comment: "Title of button to save delivery limit settings to pump")
    }

    public func syncButtonDetailText(for viewController: DeliveryLimitSettingsTableViewController) -> String? {
        return nil
    }

    public func deliveryLimitSettingsTableViewControllerIsReadOnly(_ viewController: DeliveryLimitSettingsTableViewController) -> Bool {
        return false
    }
}


// MARK: - BasalScheduleTableViewControllerSyncSource
extension MinimedPumpManager {
    public func syncScheduleValues(for viewController: BasalScheduleTableViewController, completion: @escaping (SyncBasalScheduleResult<Double>) -> Void) {
        pumpOps.runSession(withName: "Save Basal Profile", using: rileyLinkDeviceProvider.firstConnectedDevice) { (session) in
            guard let session = session else {
                completion(.failure(PumpManagerError.connection(MinimedPumpManagerError.noRileyLink)))
                return
            }

            do {
                let newSchedule = BasalSchedule(repeatingScheduleValues: viewController.scheduleItems)
                try session.setBasalSchedule(newSchedule, for: .standard)

                completion(.success(scheduleItems: viewController.scheduleItems, timeZone: session.pump.timeZone))
            } catch let error {
                self.log.error("Save basal profile failed: %{public}@", String(describing: error))
                completion(.failure(error))
            }
        }
    }

    public func syncButtonTitle(for viewController: BasalScheduleTableViewController) -> String {
        return LocalizedString("Save to Pump…", comment: "Title of button to save basal profile to pump")
    }

    public func syncButtonDetailText(for viewController: BasalScheduleTableViewController) -> String? {
        return nil
    }

    public func basalScheduleTableViewControllerIsReadOnly(_ viewController: BasalScheduleTableViewController) -> Bool {
        return false
    }
}
