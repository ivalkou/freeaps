//
//  MinimedHUDProvider.swift
//  MinimedKitUI
//
//  Created by Pete Schwamb on 2/4/19.
//  Copyright © 2019 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit
import LoopKitUI
import MinimedKit

class MinimedHUDProvider: HUDProvider {

    var managerIdentifier: String {
        return MinimedPumpManager.managerIdentifier
    }

    private var state: MinimedPumpManagerState {
        didSet {
            guard visible else {
                return
            }

            if oldValue.batteryPercentage != state.batteryPercentage {
                self.updateBatteryView()
            }

            if oldValue.lastReservoirReading != state.lastReservoirReading {
                self.updateReservoirView()
            }
        }
    }

    private let pumpManager: MinimedPumpManager

    public init(pumpManager: MinimedPumpManager) {
        self.pumpManager = pumpManager
        self.state = pumpManager.state
        pumpManager.stateObservers.insert(self, queue: .main)
    }

    var visible: Bool = false {
        didSet {
            if oldValue != visible && visible {
                self.updateBatteryView()
                self.updateReservoirView()
            }
        }
    }

    private weak var reservoirView: ReservoirVolumeHUDView?

    private weak var batteryView: BatteryLevelHUDView?

    private func updateReservoirView() {
        if let lastReservoirVolume = state.lastReservoirReading,
            let reservoirView = reservoirView
        {
            let reservoirLevel = (lastReservoirVolume.units / pumpManager.pumpReservoirCapacity).clamped(to: 0...1.0)
            reservoirView.level = reservoirLevel
            reservoirView.setReservoirVolume(volume: lastReservoirVolume.units, at: lastReservoirVolume.validAt)
        }
    }

    private func updateBatteryView() {
        if let batteryView = batteryView {
            batteryView.batteryLevel = state.batteryPercentage
        }
    }

    public func createHUDViews() -> [BaseHUDView] {

        reservoirView = ReservoirVolumeHUDView.instantiate()
        batteryView = BatteryLevelHUDView.instantiate()

        if visible {
            updateReservoirView()
            updateBatteryView()
        }

        return [reservoirView, batteryView].compactMap { $0 }
    }

    public func didTapOnHUDView(_ view: BaseHUDView) -> HUDTapAction? {
        return HUDTapAction.presentViewController(pumpManager.settingsViewController())
    }

    public var hudViewsRawState: HUDProvider.HUDViewsRawState {
        var rawValue: HUDProvider.HUDViewsRawState = [
            "pumpReservoirCapacity": pumpManager.pumpReservoirCapacity
        ]

        rawValue["batteryPercentage"] = state.batteryPercentage

        if let lastReservoirReading = state.lastReservoirReading {
            rawValue["lastReservoirReading"] = lastReservoirReading.rawValue
        }

        return rawValue
    }

    public static func createHUDViews(rawValue: HUDProvider.HUDViewsRawState) -> [BaseHUDView] {
        guard let pumpReservoirCapacity = rawValue["pumpReservoirCapacity"] as? Double else {
            return []
        }

        let batteryPercentage = rawValue["batteryPercentage"] as? Double

        let reservoirVolumeHUDView = ReservoirVolumeHUDView.instantiate()
        if let rawLastReservoirReading = rawValue["lastReservoirReading"] as? ReservoirReading.RawValue,
            let lastReservoirReading = ReservoirReading(rawValue: rawLastReservoirReading)
        {
            let reservoirLevel = (lastReservoirReading.units / pumpReservoirCapacity).clamped(to: 0...1.0)
            reservoirVolumeHUDView.level = reservoirLevel
            reservoirVolumeHUDView.setReservoirVolume(volume: lastReservoirReading.units, at: lastReservoirReading.validAt)
        }

        let batteryLevelHUDView = BatteryLevelHUDView.instantiate()
        batteryLevelHUDView.batteryLevel = batteryPercentage

        return [reservoirVolumeHUDView, batteryLevelHUDView]
    }
}

extension MinimedHUDProvider: MinimedPumpManagerStateObserver {
    func didUpdatePumpManagerState(_ state: MinimedPumpManagerState) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.state = state
    }
}
