//
//  OmniBLEPumpManager+UI.swift
//  OmniBLE
//
//  Based on OmniKitUI/PumpManager/OmnipodPumpManager+UI.swift
//  Created by Pete Schwamb on 8/4/18.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

import UIKit
import LoopKit
import LoopKitUI

extension OmniBLEPumpManager: PumpManagerUI {
    
    static public func setupViewController() -> (UIViewController & PumpManagerSetupViewController & CompletionNotifying) {
        return OmniBLEPumpManagerSetupViewController.instantiateFromStoryboard()
    }
    
    public func settingsViewController() -> (UIViewController & CompletionNotifying) {
        let settings = OmniBLESettingsViewController(pumpManager: self)
        let nav = SettingsNavigationViewController(rootViewController: settings)
        return nav
    }
    
    public var smallImage: UIImage? {
        return UIImage(named: "Pod", in: Bundle(for: OmniBLESettingsViewController.self), compatibleWith: nil)!
    }
    
    public func hudProvider() -> HUDProvider? {
        return OmniBLEHUDProvider(pumpManager: self)
    }
    
    public static func createHUDViews(rawValue: HUDProvider.HUDViewsRawState) -> [BaseHUDView] {
        return OmniBLEHUDProvider.createHUDViews(rawValue: rawValue)
    }

}

// MARK: - DeliveryLimitSettingsTableViewControllerSyncSource
extension OmniBLEPumpManager {
    public func syncDeliveryLimitSettings(for viewController: DeliveryLimitSettingsTableViewController, completion: @escaping (DeliveryLimitSettingsResult) -> Void) {
        guard let maxBasalRate = viewController.maximumBasalRatePerHour,
            let maxBolus = viewController.maximumBolus else
        {
            completion(.failure(PodCommsError.invalidData))
            return
        }
        
        completion(.success(maximumBasalRatePerHour: maxBasalRate, maximumBolus: maxBolus))
    }
    
    public func syncButtonTitle(for viewController: DeliveryLimitSettingsTableViewController) -> String {
        return LocalizedString("Save", comment: "Title of button to save delivery limit settings")    }
    
    public func syncButtonDetailText(for viewController: DeliveryLimitSettingsTableViewController) -> String? {
        return nil
    }
    
    public func deliveryLimitSettingsTableViewControllerIsReadOnly(_ viewController: DeliveryLimitSettingsTableViewController) -> Bool {
        return false
    }
}

// MARK: - BasalScheduleTableViewControllerSyncSource
extension OmniBLEPumpManager {

    public func syncScheduleValues(for viewController: BasalScheduleTableViewController, completion: @escaping (SyncBasalScheduleResult<Double>) -> Void) {
        let newSchedule = BasalSchedule(repeatingScheduleValues: viewController.scheduleItems)
        setBasalSchedule(newSchedule) { (error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(scheduleItems: viewController.scheduleItems, timeZone: self.state.timeZone))
            }
        }
    }

    public func syncButtonTitle(for viewController: BasalScheduleTableViewController) -> String {
        if self.hasActivePod {
            return LocalizedString("Sync With Pod", comment: "Title of button to sync basal profile from pod")
        } else {
            return LocalizedString("Save", comment: "Title of button to sync basal profile when no pod paired")
        }
    }

    public func syncButtonDetailText(for viewController: BasalScheduleTableViewController) -> String? {
        return nil
    }

    public func basalScheduleTableViewControllerIsReadOnly(_ viewController: BasalScheduleTableViewController) -> Bool {
        return false
    }
}
