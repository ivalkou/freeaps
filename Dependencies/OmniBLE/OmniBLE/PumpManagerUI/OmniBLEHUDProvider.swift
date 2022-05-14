//
//  OmniBLEHUDProvider.swift
//  OmniBLE
//
//  Based on OmniKitUI/PumpManager/OmniBLEHUDProvider.swift
//  Created by Pete Schwamb on 11/26/18.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI

internal class OmniBLEHUDProvider: NSObject, HUDProvider, PodStateObserver {
    var managerIdentifier: String {
        return OmniBLEPumpManager.managerIdentifier
    }
    
    private var podState: PodState? {
        didSet {
            guard visible else {
                return
            }

            guard oldValue != podState else {
                return
            }

            if oldValue?.lastInsulinMeasurements != podState?.lastInsulinMeasurements {
                updateReservoirView()
            }
            
            if oldValue?.isFaulted != podState?.isFaulted {
                updateFaultDisplay()
            }
            
            if oldValue != nil && podState == nil {
                updateReservoirView()
                updateFaultDisplay()
            }

            if (oldValue == nil || podState == nil) && (oldValue != nil || podState != nil) {
                updatePodLifeView()
            }
        }
    }
    
    private let pumpManager: OmniBLEPumpManager
    
    private var reservoirView: OmniBLEReservoirView?
    
    private var podLifeView: PodLifeHUDView?

    var visible: Bool = false {
        didSet {
            if oldValue != visible && visible {
                hudDidAppear()
            }
        }
    }
    
    public init(pumpManager: OmniBLEPumpManager) {
        self.pumpManager = pumpManager
        self.podState = pumpManager.state.podState
        super.init()
        self.pumpManager.addPodStateObserver(self, queue: .main)
    }
    
    private func updateReservoirView() {
        if let lastInsulinMeasurements = podState?.lastInsulinMeasurements,
            let reservoirView = reservoirView,
            let podState = podState
        {
            let reservoirVolume = lastInsulinMeasurements.reservoirLevel

            let reservoirLevel = reservoirVolume?.asReservoirPercentage()

            var reservoirAlertState: ReservoirAlertState = .ok
            for (_, alert) in podState.activeAlerts {
                if case .lowReservoir = alert {
                    reservoirAlertState = .lowReservoir
                    break
                }
            }

            reservoirView.update(volume: reservoirVolume, at: lastInsulinMeasurements.validTime, level: reservoirLevel, reservoirAlertState: reservoirAlertState)
        }
    }
    
    private func updateFaultDisplay() {
        if let podLifeView = podLifeView {
            if let podState = self.podState, podState.isFaulted {
                podLifeView.alertState = .fault
            } else {
                podLifeView.alertState = .none
            }
        }
    }
    
    private func updatePodLifeView() {
        guard let podLifeView = podLifeView else {
            return
        }
        if let activatedAt = podState?.activatedAt, let expiresAt = podState?.expiresAt  {
            let lifetime = expiresAt.timeIntervalSince(activatedAt)
            podLifeView.setPodLifeCycle(startTime: activatedAt, lifetime: lifetime)
        } else {
            podLifeView.setPodLifeCycle(startTime: Date(), lifetime: Pod.nominalPodLife)
        }
    }
    
    public func createHUDViews() -> [BaseHUDView] {
        self.reservoirView = OmniBLEReservoirView.instantiate()
        self.updateReservoirView()

        podLifeView = PodLifeHUDView.instantiate()

        if visible {
            updatePodLifeView()
            updateFaultDisplay()
        }

        return [reservoirView, podLifeView].compactMap { $0 }
    }
    
    public func didTapOnHUDView(_ view: BaseHUDView) -> HUDTapAction? {
        if let podState = self.podState, podState.isFaulted {
            return HUDTapAction.presentViewController(PodReplacementNavigationController.instantiatePodReplacementFlow(pumpManager))
        } else {
            return HUDTapAction.presentViewController(pumpManager.settingsViewController())
        }
    }
    
    func hudDidAppear() {
        updatePodLifeView()
        updateReservoirView()
        updateFaultDisplay()
        pumpManager.refreshStatus(emitConfirmationBeep: false)
    }

    func hudDidDisappear(_ animated: Bool) {
        if let podLifeView = podLifeView {
            podLifeView.pauseUpdates()
        }
    }
    
    public var hudViewsRawState: HUDProvider.HUDViewsRawState {
        var rawValue: HUDProvider.HUDViewsRawState = [:]
        
        if let podState = podState {
            rawValue["podActivatedAt"] = podState.activatedAt
            let lifetime: TimeInterval
            if let expiresAt = podState.expiresAt, let activatedAt = podState.activatedAt {
                lifetime = expiresAt.timeIntervalSince(activatedAt)
            } else {
                lifetime = 0
            }
            rawValue["lifetime"] = lifetime
            rawValue["alerts"] = podState.activeAlerts.values.map { $0.rawValue }
        }
        
        if let lastInsulinMeasurements = podState?.lastInsulinMeasurements {
            rawValue["reservoirVolume"] = lastInsulinMeasurements.reservoirLevel
            rawValue["validTime"] = lastInsulinMeasurements.validTime
        }
        
        return rawValue
    }
    
    public static func createHUDViews(rawValue: HUDProvider.HUDViewsRawState) -> [BaseHUDView] {
        guard let podActivatedAt = rawValue["podActivatedAt"] as? Date,
            let lifetime = rawValue["lifetime"] as? Double,
            let rawAlerts = rawValue["alerts"] as? [PodAlert.RawValue] else
        {
            return []
        }
        
        let alerts = rawAlerts.compactMap { PodAlert.init(rawValue: $0) }
        let reservoirVolume = rawValue["reservoirVolume"] as? Double
        let validTime = rawValue["validTime"] as? Date
        
        let reservoirView = OmniBLEReservoirView.instantiate()
        if let validTime = validTime
        {
            let reservoirLevel = reservoirVolume?.asReservoirPercentage()
            var reservoirAlertState: ReservoirAlertState = .ok
            for alert in alerts {
                if case .lowReservoir = alert {
                    reservoirAlertState = .lowReservoir
                }
            }
            reservoirView.update(volume: reservoirVolume, at: validTime, level: reservoirLevel, reservoirAlertState: reservoirAlertState)
        }
        
        let podLifeHUDView = PodLifeHUDView.instantiate()
        podLifeHUDView.setPodLifeCycle(startTime: podActivatedAt, lifetime: lifetime)
        
        return [reservoirView, podLifeHUDView]
    }
    
    func podConnectionStateDidChange(isConnected: Bool) {
        // ignore for now
    }

    func podStateDidUpdate(_ podState: PodState?) {
        self.podState = podState
    }
}

extension Double {
    func asReservoirPercentage() -> Double {
        return min(1, max(0, self / Pod.reservoirCapacity))
    }
}
