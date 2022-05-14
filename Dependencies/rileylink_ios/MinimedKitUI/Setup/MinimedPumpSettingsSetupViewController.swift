//
//  MinimedPumpSettingsSetupViewController.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit
import LoopKitUI
import MinimedKit

class MinimedPumpSettingsSetupViewController: SetupTableViewController {

    var pumpManager: MinimedPumpManager?

    private var pumpManagerSetupViewController: MinimedPumpManagerSetupViewController? {
        return navigationController as? MinimedPumpManagerSetupViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if pumpManager == nil {
            navigationController?.popViewController(animated: true)
        }
    }

    fileprivate lazy var quantityFormatter: QuantityFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.numberFormatter.minimumFractionDigits = 0
        quantityFormatter.numberFormatter.maximumFractionDigits = 3

        return quantityFormatter
    }()

    // MARK: - Table view data source

    private enum Section: Int {
        case description
        case configuration

        static let count = 2
    }

    private enum ConfigurationRow: Int {
        case basalRates
        case deliveryLimits

        static let count = 2
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
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

                if let basalRateSchedule = pumpManagerSetupViewController?.basalSchedule {
                    let unit = HKUnit.internationalUnit()
                    let total = HKQuantity(unit: unit, doubleValue: basalRateSchedule.total())
                    cell.detailTextLabel?.text = quantityFormatter.string(from: total, for: unit)
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
                guard let pumpManager = pumpManager else {
                    return
                }
                let vc = BasalScheduleTableViewController(allowedBasalRates: pumpManager.supportedBasalRates, maximumScheduleItemCount: pumpManager.maximumBasalScheduleEntryCount, minimumTimeInterval: pumpManager.minimumBasalScheduleEntryDuration)

                if let profile = pumpManagerSetupViewController?.basalSchedule {
                    vc.scheduleItems = profile.items
                    vc.timeZone = profile.timeZone
                } else {
                    vc.timeZone = pumpManager.state.timeZone
                }

                vc.title = sender?.textLabel?.text
                vc.delegate = self
                vc.syncSource = pumpManager

                show(vc, sender: sender)
            case .deliveryLimits:
                let vc = DeliveryLimitSettingsTableViewController(style: .grouped)

                vc.maximumBasalRatePerHour = pumpManagerSetupViewController?.maxBasalRateUnitsPerHour
                vc.maximumBolus = pumpManagerSetupViewController?.maxBolusUnits

                vc.title = sender?.textLabel?.text
                vc.delegate = self
                vc.syncSource = pumpManager

                show(vc, sender: sender)
            }
        }
    }

    override func continueButtonPressed(_ sender: Any) {
        if let setupViewController = navigationController as? MinimedPumpManagerSetupViewController,
            let pumpManager = pumpManager
        {
            super.continueButtonPressed(sender)
            setupViewController.pumpManagerSetupComplete(pumpManager)
        }
    }
}

extension MinimedPumpSettingsSetupViewController: DailyValueScheduleTableViewControllerDelegate {
    func dailyValueScheduleTableViewControllerWillFinishUpdating(_ controller: DailyValueScheduleTableViewController) {
        if let controller = controller as? SingleValueScheduleTableViewController {
            pumpManagerSetupViewController?.basalSchedule = BasalRateSchedule(dailyItems: controller.scheduleItems, timeZone: controller.timeZone)
        }

        tableView.reloadRows(at: [[Section.configuration.rawValue, ConfigurationRow.basalRates.rawValue]], with: .none)
    }
}

extension MinimedPumpSettingsSetupViewController: DeliveryLimitSettingsTableViewControllerDelegate {
    func deliveryLimitSettingsTableViewControllerDidUpdateMaximumBasalRatePerHour(_ vc: DeliveryLimitSettingsTableViewController) {
        pumpManagerSetupViewController?.maxBasalRateUnitsPerHour = vc.maximumBasalRatePerHour

        tableView.reloadRows(at: [[Section.configuration.rawValue, ConfigurationRow.deliveryLimits.rawValue]], with: .none)
    }

    func deliveryLimitSettingsTableViewControllerDidUpdateMaximumBolus(_ vc: DeliveryLimitSettingsTableViewController) {
        pumpManagerSetupViewController?.maxBolusUnits = vc.maximumBolus

        tableView.reloadRows(at: [[Section.configuration.rawValue, ConfigurationRow.deliveryLimits.rawValue]], with: .none)
    }
}
