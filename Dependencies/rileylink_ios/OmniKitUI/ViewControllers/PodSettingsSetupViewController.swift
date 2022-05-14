//
//  PodSettingsSetupViewController.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 9/25/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

import UIKit
import HealthKit
import LoopKit
import LoopKitUI
import OmniKit

class PodSettingsSetupViewController: SetupTableViewController {
    
    private var pumpManagerSetupViewController: OmnipodPumpManagerSetupViewController? {
        return navigationController as? OmnipodPumpManagerSetupViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        updateContinueButton()
        
        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
    }
    
    fileprivate lazy var quantityFormatter: QuantityFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.numberFormatter.minimumFractionDigits = 0
        quantityFormatter.numberFormatter.maximumFractionDigits = 3
        
        return quantityFormatter
    }()

    func updateContinueButton() {
        let enabled: Bool
        if pumpManagerSetupViewController?.maxBolusUnits == nil || pumpManagerSetupViewController?.maxBasalRateUnitsPerHour == nil {
            enabled = false
        }
        else if let basalSchedule = pumpManagerSetupViewController?.basalSchedule {
            enabled = !basalSchedule.items.isEmpty && !scheduleHasError
        } else {
            enabled = false
        }
        footerView.primaryButton.isEnabled = enabled
    }

    var scheduleHasError: Bool {
        return scheduleErrorMessage != nil
    }

    var scheduleErrorMessage: String? {
        if let basalRateSchedule = pumpManagerSetupViewController?.basalSchedule {
            if basalRateSchedule.items.count > Pod.maximumBasalScheduleEntryCount {
                return LocalizedString("Too many entries", comment: "The error message shown when Loop's basal schedule has more entries than the pod can support")
            }
            let allowedRates = Pod.supportedBasalRates
            if basalRateSchedule.items.contains(where: {!allowedRates.contains($0.value)}) {
                return LocalizedString("Invalid entry", comment: "The error message shown when Loop's basal schedule has an unsupported rate")
            }
        }
        return nil
    }

    // MARK: - Table view data source
    
    private enum Section: Int, CaseIterable {
        case description
        case configuration
    }
    
    private enum ConfigurationRow: Int, CaseIterable {
        case deliveryLimits
        case basalRates
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .description:
            return 1
        case .configuration:
            return 2
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .description:
            return tableView.dequeueReusableCell(withIdentifier: "DescriptionCell", for: indexPath)
        case .configuration:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            
            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .basalRates:
                cell.textLabel?.text = LocalizedString("Basal Rates", comment: "The title text for the basal rate schedule")
                
                if let basalRateSchedule = pumpManagerSetupViewController?.basalSchedule, !basalRateSchedule.items.isEmpty {
                    if let errorMessage = scheduleErrorMessage {
                        cell.detailTextLabel?.text = errorMessage
                    } else {
                        let unit = HKUnit.internationalUnit()
                        let total = HKQuantity(unit: unit, doubleValue: basalRateSchedule.total())
                        cell.detailTextLabel?.text = quantityFormatter.string(from: total, for: unit)
                    }
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.TapToSetString
                }
            case .deliveryLimits:
                cell.textLabel?.text = LocalizedString("Delivery Limits", comment: "Title text for delivery limits")
                
                if pumpManagerSetupViewController?.maxBolusUnits == nil || pumpManagerSetupViewController?.maxBasalRateUnitsPerHour == nil {
                    cell.detailTextLabel?.text = SettingsTableViewCell.TapToSetString
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.EnabledString
                }
            }
            
            cell.accessoryType = .disclosureIndicator
            
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .description:
            return false
        case .configuration:
            return true
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sender = tableView.cellForRow(at: indexPath)
        
        switch Section(rawValue: indexPath.section)! {
        case .description:
            break
        case .configuration:
            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .basalRates:
                let vc = BasalScheduleTableViewController(allowedBasalRates: Pod.supportedBasalRates, maximumScheduleItemCount: Pod.maximumBasalScheduleEntryCount, minimumTimeInterval: Pod.minimumBasalScheduleEntryDuration)
                
                if let profile = pumpManagerSetupViewController?.basalSchedule {
                    vc.scheduleItems = profile.items
                    vc.timeZone = profile.timeZone
                } else {
                    vc.scheduleItems = []
                    vc.timeZone = .currentFixed
                }
                
                vc.title = sender?.textLabel?.text
                vc.delegate = self
                
                show(vc, sender: sender)
            case .deliveryLimits:
                let vc = DeliveryLimitSettingsTableViewController(style: .grouped)
                
                vc.maximumBasalRatePerHour = pumpManagerSetupViewController?.maxBasalRateUnitsPerHour
                vc.maximumBolus = pumpManagerSetupViewController?.maxBolusUnits
                
                vc.title = sender?.textLabel?.text
                vc.delegate = self
                
                show(vc, sender: sender)
            }
        }
    }
}

extension PodSettingsSetupViewController: DailyValueScheduleTableViewControllerDelegate {
    func dailyValueScheduleTableViewControllerWillFinishUpdating(_ controller: DailyValueScheduleTableViewController) {
        if let controller = controller as? BasalScheduleTableViewController {
            
            pumpManagerSetupViewController?.basalSchedule = BasalRateSchedule(dailyItems: controller.scheduleItems, timeZone: controller.timeZone)

            footerView.primaryButton.isEnabled = controller.scheduleItems.count > 0 && !scheduleHasError
        }
        
        tableView.reloadRows(at: [[Section.configuration.rawValue, ConfigurationRow.basalRates.rawValue]], with: .none)
    }
}

extension PodSettingsSetupViewController: DeliveryLimitSettingsTableViewControllerDelegate {
    func deliveryLimitSettingsTableViewControllerDidUpdateMaximumBasalRatePerHour(_ vc: DeliveryLimitSettingsTableViewController) {
        pumpManagerSetupViewController?.maxBasalRateUnitsPerHour = vc.maximumBasalRatePerHour
        
        tableView.reloadRows(at: [[Section.configuration.rawValue, ConfigurationRow.deliveryLimits.rawValue]], with: .none)
    }
    
    func deliveryLimitSettingsTableViewControllerDidUpdateMaximumBolus(_ vc: DeliveryLimitSettingsTableViewController) {
        pumpManagerSetupViewController?.maxBolusUnits = vc.maximumBolus
        
        tableView.reloadRows(at: [[Section.configuration.rawValue, ConfigurationRow.deliveryLimits.rawValue]], with: .none)
    }
}
