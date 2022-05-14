//
//  OmniBLEPumpManager.swift
//  OmniBLE
//
//  Based on OmniKit/PumpManager/OmnipodPumpManager.swift
//  Created by Pete Schwamb on 8/4/18.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
import UserNotifications
import os.log


public enum ReservoirAlertState {
    case ok
    case lowReservoir
    case empty
}

public protocol PodStateObserver: AnyObject {
    func podStateDidUpdate(_ state: PodState?)
    func podConnectionStateDidChange(isConnected: Bool)
}

public enum OmniBLEPumpManagerError: Error {
    case noPodPaired
    case podAlreadyPaired
    case notReadyForCannulaInsertion
}

extension OmniBLEPumpManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noPodPaired:
            return LocalizedString("No pod paired", comment: "Error message shown when no pod is paired")
        case .podAlreadyPaired:
            return LocalizedString("Pod already paired", comment: "Error message shown when user cannot pair because pod is already paired")
        case .notReadyForCannulaInsertion:
            return LocalizedString("Pod is not in a state ready for cannula insertion", comment: "Error message when cannula insertion fails because the pod is in an unexpected state")
        }
    }

    public var failureReason: String? {
        switch self {
        case .noPodPaired:
            return nil
        case .podAlreadyPaired:
            return nil
        case .notReadyForCannulaInsertion:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noPodPaired:
            return LocalizedString("Please pair a new pod", comment: "Recover suggestion shown when no pod is paired")
        case .podAlreadyPaired:
            return nil
        case .notReadyForCannulaInsertion:
            return nil
        }
    }
}

public class OmniBLEPumpManager: DeviceManager {

    public init(state: OmniBLEPumpManagerState) {
        self.lockedState = Locked(state)
        let podComms = PodComms(podState: state.podState, myId: state.controllerId, podId: state.podId)
        self.lockedPodComms = Locked(podComms)

        self.podComms.delegate = self
        self.podComms.messageLogger = self
    }

    public required convenience init?(rawState: PumpManager.RawStateValue) {
        guard let state = OmniBLEPumpManagerState(rawValue: rawState) else
        {
            return nil
        }

        self.init(state: state)
    }

    public var deviceBLEName: String? {
        return self.podComms.manager?.peripheral.name
    }

    private var podComms: PodComms {
        get {
            return lockedPodComms.value
        }
        set {
            lockedPodComms.value = newValue
        }
    }

    private let lockedPodComms: Locked<PodComms>

    private let podStateObservers = WeakSynchronizedSet<PodStateObserver>()

    public var state: OmniBLEPumpManagerState {
        return lockedState.value
    }

    private func setState(_ changes: (_ state: inout OmniBLEPumpManagerState) -> Void) -> Void {
        return setStateWithResult(changes)
    }

    @discardableResult
    private func mutateState(_ changes: (_ state: inout OmniBLEPumpManagerState) -> Void) -> OmniBLEPumpManagerState {
        return setStateWithResult({ (state) -> OmniBLEPumpManagerState in
            changes(&state)
            return state
        })
    }

    private func setStateWithResult<ReturnType>(_ changes: (_ state: inout OmniBLEPumpManagerState) -> ReturnType) -> ReturnType {
        var oldValue: OmniBLEPumpManagerState!
        var returnType: ReturnType!
        let newValue = lockedState.mutate { (state) in
            oldValue = state
            returnType = changes(&state)
        }

        guard oldValue != newValue else {
            return returnType
        }

        if oldValue.podState != newValue.podState {
            podStateObservers.forEach { (observer) in
                observer.podStateDidUpdate(newValue.podState)
            }

            if oldValue.podState?.lastInsulinMeasurements?.reservoirLevel != newValue.podState?.lastInsulinMeasurements?.reservoirLevel {
                if let lastInsulinMeasurements = newValue.podState?.lastInsulinMeasurements, let reservoirLevel = lastInsulinMeasurements.reservoirLevel {
                    self.pumpDelegate.notify({ (delegate) in
                        self.log.info("DU: updating reservoir level %{public}@", String(describing: reservoirLevel))
                        delegate?.pumpManager(self, didReadReservoirValue: reservoirLevel, at: lastInsulinMeasurements.validTime) { _ in }
                    })
                }
            }
        }


        // Ideally we ensure that oldValue.rawValue != newValue.rawValue, but the types aren't
        // defined as equatable
        pumpDelegate.notify { (delegate) in
            delegate?.pumpManagerDidUpdateState(self)
        }

        let oldStatus = status(for: oldValue)
        let newStatus = status(for: newValue)

        if oldStatus != newStatus {
            notifyStatusObservers(oldStatus: oldStatus)
        }

        // Reschedule expiration notification if relevant values change
        if oldValue.expirationReminderDate != newValue.expirationReminderDate ||
            oldValue.podState?.expiresAt != newValue.podState?.expiresAt
        {
            schedulePodExpirationNotification(for: newValue)
        }

        return returnType
    }

    private let lockedState: Locked<OmniBLEPumpManagerState>

    private let statusObservers = WeakSynchronizedSet<PumpManagerStatusObserver>()

    private func notifyStatusObservers(oldStatus: PumpManagerStatus) {
        let status = self.status
        pumpDelegate.notify { (delegate) in
            delegate?.pumpManager(self, didUpdate: status, oldStatus: oldStatus)
        }
        statusObservers.forEach { (observer) in
            observer.pumpManager(self, didUpdate: status, oldStatus: oldStatus)
        }
    }

    private func logDeviceCommunication(_ message: String, type: DeviceLogEntryType = .send) {
        let podAddress = String(format: "%04X", self.state.podId)
        self.pumpDelegate.notify { (delegate) in
            delegate?.deviceManager(self, logEventForDeviceIdentifier: podAddress, type: type, message: message, completion: nil)
        }
    }

    // Not persisted
    var provideHeartbeat: Bool = false

    private var lastHeartbeat: Date = .distantPast

    public func setMustProvideBLEHeartbeat(_ mustProvideBLEHeartbeat: Bool) {
        provideHeartbeat = mustProvideBLEHeartbeat
    }

    private func issueHeartbeatIfNeeded() {
        let now = Date()
        if self.provideHeartbeat, now.timeIntervalSince(lastHeartbeat) > .minutes(2) {
            self.pumpDelegate.notify { (delegate) in
                delegate?.pumpManagerBLEHeartbeatDidFire(self)
            }
            self.lastHeartbeat = now
        }
    }

    var isConnected: Bool {
        podComms.manager?.peripheral.state == .connected
    }

    func podConnectionStateDidChange(isConnected: Bool) {
        podStateObservers.forEach { (observer) in
            observer.podConnectionStateDidChange(isConnected: isConnected)
        }
    }

    private let pumpDelegate = WeakSynchronizedDelegate<PumpManagerDelegate>()

    public let log = OSLog(category: "OmniBLEPumpManager")

    private var lastLoopRecommendation: Date?

    // MARK: - CustomDebugStringConvertible

    public var debugDescription: String {
        let lines = [
            "## OmniBLEPumpManager",
            "podComms: \(String(reflecting: podComms))",
            "state: \(String(reflecting: state))",
            "status: \(String(describing: status))",
            "podStateObservers.count: \(podStateObservers.cleanupDeallocatedElements().count)",
            "statusObservers.count: \(statusObservers.cleanupDeallocatedElements().count)",
        ]
        return lines.joined(separator: "\n")
    }
}

extension OmniBLEPumpManager {
    // MARK: - PodStateObserver

    public func addPodStateObserver(_ observer: PodStateObserver, queue: DispatchQueue) {
        podStateObservers.insert(observer, queue: queue)
    }

    public func removePodStateObserver(_ observer: PodStateObserver) {
        podStateObservers.removeElement(observer)
    }

    private func status(for state: OmniBLEPumpManagerState) -> PumpManagerStatus {
        return PumpManagerStatus(
            timeZone: state.timeZone,
            device: device(for: state),
            pumpBatteryChargeRemaining: nil,
            basalDeliveryState: basalDeliveryState(for: state),
            bolusState: bolusState(for: state)
        )
    }

    private func device(for state: OmniBLEPumpManagerState) -> HKDevice {
        if let podState = state.podState {
            return HKDevice(
                name: type(of: self).managerIdentifier,
                manufacturer: "Insulet",
                model: "Dash",
                hardwareVersion: String(podState.productId),
                firmwareVersion: podState.firmwareVersion + " " + podState.bleFirmwareVersion,
                softwareVersion: String(OmniBLEVersionNumber),
                localIdentifier: String(format:"%04X", podState.address),
                udiDeviceIdentifier: nil
            )
        } else {
            return HKDevice(
                name: type(of: self).managerIdentifier,
                manufacturer: "Insulet",
                model: "Dash",
                hardwareVersion: nil,
                firmwareVersion: nil,
                softwareVersion: String(OmniBLEVersionNumber),
                localIdentifier: nil,
                udiDeviceIdentifier: nil
            )
        }
    }

    private func basalDeliveryState(for state: OmniBLEPumpManagerState) -> PumpManagerStatus.BasalDeliveryState {
        guard let podState = state.podState else {
            return .suspended(state.lastPumpDataReportDate ?? .distantPast)
        }

        switch state.suspendEngageState {
        case .engaging:
            return .suspending
        case .disengaging:
            return .resuming
        case .stable:
            break
        }

        switch state.tempBasalEngageState {
        case .engaging:
            return .initiatingTempBasal
        case .disengaging:
            return .cancelingTempBasal
        case .stable:
            if let tempBasal = podState.unfinalizedTempBasal, !tempBasal.isFinished() {
                return .tempBasal(DoseEntry(tempBasal))
            }
            switch podState.suspendState {
            case .resumed(let date):
                return .active(date)
            case .suspended(let date):
                return .suspended(date)
            }
        }
    }

    private func bolusState(for state: OmniBLEPumpManagerState) -> PumpManagerStatus.BolusState {
        guard let podState = state.podState else {
            return .none
        }

        switch state.bolusEngageState {
        case .engaging:
            return .initiating
        case .disengaging:
            return .canceling
        case .stable:
            if let bolus = podState.unfinalizedBolus, !bolus.isFinished() {
                return .inProgress(DoseEntry(bolus))
            }
        }
        return .none
    }

    // Returns true if there an unfinishedDose for a manual bolus (independent of whether it is finished)
    private var hasUnfinalizedManualBolus: Bool {
        if let automatic = state.podState?.unfinalizedBolus?.automatic, !automatic {
            return true
        }
        return false
    }

    // Returns true if there an unfinishedDose for a manual temp basal (independent of whether it is finished)
    private var hasUnfinalizedManualTempBasal: Bool {
        if let automatic = state.podState?.unfinalizedTempBasal?.automatic, !automatic {
            return true
        }
        return false
    }

    // Returns a suitable beep command MessageBlock based the current confirmationBeeps setting
    // and whether there is an unfinializedDose for a manual temp basal &/or a manual bolus.
    private func beepMessageBlock(beepType: BeepConfigType) -> MessageBlock? {
        guard self.confirmationBeeps else {
            return nil
        }

        // Enable temp basal & basal completion beeps if there is a cooresponding manual unfinalizedDose
        let beepMessageBlock = BeepConfigCommand(
            beepConfigType: beepType,
            tempBasalCompletionBeep: hasUnfinalizedManualTempBasal,
            bolusCompletionBeep: hasUnfinalizedManualBolus
        )

        return beepMessageBlock
    }

    private var shouldBeepForAutomaticBolus: Bool {
        return self.confirmationBeeps && self.extendedBeeps
    }

    private var shouldBeepForAutomaticTempBasal: Bool {
        let tempBasalConfirmationBeeps = true
        return self.shouldBeepForAutomaticBolus && tempBasalConfirmationBeeps
    }

    // Thread-safe
    public var hasActivePod: Bool {
        // TODO: Should this check be done automatically before each session?
        return state.hasActivePod
    }

    // Thread-safe
    public var hasSetupPod: Bool {
        return state.hasSetupPod
    }

    // Thread-safe
    public var expirationReminderDate: Date? {
        get {
            return state.expirationReminderDate
        }
        set {
            // Setting a new value reschedules notifications
            setState { (state) in
                state.expirationReminderDate = newValue
            }
        }
    }

    // Thread-safe
    public var confirmationBeeps: Bool {
        get {
            return state.confirmationBeeps
        }
        set {
            setState { (state) in
                state.confirmationBeeps = newValue
            }
        }
    }

    // Thread-safe
    public var extendedBeeps: Bool {
        get {
            return state.extendedBeeps
        }
        set {
            setState { (state) in
                state.extendedBeeps = newValue
            }
        }
    }

    // MARK: - Notifications

    static let podExpirationNotificationIdentifier = "OmniBLE:\(LoopNotificationCategory.pumpExpired.rawValue)"

    func schedulePodExpirationNotification(for state: OmniBLEPumpManagerState) {
        guard let expirationReminderDate = state.expirationReminderDate,
            expirationReminderDate.timeIntervalSinceNow > 0,
            let expiresAt = state.podState?.expiresAt
        else {
            pumpDelegate.notify { (delegate) in
                delegate?.clearNotification(for: self, identifier: OmniBLEPumpManager.podExpirationNotificationIdentifier)
            }
            return
        }

        let content = UNMutableNotificationContent()

        let timeBetweenNoticeAndExpiration = expiresAt.timeIntervalSince(expirationReminderDate)

        let formatter = DateComponentsFormatter()
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full

        let timeUntilExpiration = formatter.string(from: timeBetweenNoticeAndExpiration) ?? ""

        content.title = LocalizedString("Pod Expiration Notice", comment: "The title for pod expiration notification")

        content.body = String(format: LocalizedString("Time to replace your pod! Your pod will expire in %1$@", comment: "The format string for pod expiration notification body (1: time until expiration)"), timeUntilExpiration)
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = LoopNotificationCategory.pumpExpired.rawValue
        content.threadIdentifier = LoopNotificationCategory.pumpExpired.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: expirationReminderDate.timeIntervalSinceNow,
            repeats: false
        )

        pumpDelegate.notify { (delegate) in
            delegate?.scheduleNotification(for: self, identifier: OmniBLEPumpManager.podExpirationNotificationIdentifier, content: content, trigger: trigger)
        }
    }

    // MARK: - Pod comms

    // Does not support concurrent callers. Not thread-safe.
    public func forgetPod(completion: @escaping () -> Void) {

        self.podComms.forgetCurrentPod()

        let resetPodState = { (_ state: inout OmniBLEPumpManagerState) in
            if state.controllerId == CONTROLLER_ID {
                // Switch from using the common fixed controllerId to a created semi-unique one
                state.controllerId = createControllerId()
                state.podId = state.controllerId + 1
                self.log.info("Switched controllerId from %x to %x", CONTROLLER_ID, state.controllerId)
            } else {
                // Already have a created controllerId, just need to advance podId for the next pod
                let lastPodId = state.podId
                state.podId = nextPodId(lastPodId: lastPodId)
                self.log.info("Advanced podId from %x to %x", lastPodId, state.podId)
            }
            self.podComms = PodComms(podState: nil, myId: state.controllerId, podId: state.podId)
            self.podComms.delegate = self
            self.podComms.messageLogger = self

            state.podState = nil
            state.expirationReminderDate = nil
        }

        // TODO: PodState shouldn't be mutated outside of the session queue
        // TODO: Consider serializing the entire forget-pod path instead of relying on the UI to do it

        let state = mutateState { (state) in
            state.podState?.finalizeFinishedDoses()
        }

        if let dosesToStore = state.podState?.dosesToStore {
            store(doses: dosesToStore, completion: { error in
                self.setState({ (state) in
                    if error != nil {
                        state.unstoredDoses.append(contentsOf: dosesToStore)
                    }

                    resetPodState(&state)
                })
                completion()
            })
        } else {
            setState { (state) in
                resetPodState(&state)
            }

            completion()
        }
    }


    // MARK: Testing

    #if targetEnvironment(simulator)
    private func jumpStartPod(lotNo: UInt32, lotSeq: UInt32, fault: DetailedStatus? = nil, startDate: Date? = nil, mockFault: Bool) {
        let start = startDate ?? Date()
        let fakeLtk = Data(hexadecimalString: "fedcba98765432100123456789abcdef")!
        var podState = PodState(address: state.podId, ltk: fakeLtk,
            firmwareVersion: "jumpstarted", bleFirmwareVersion: "jumpstarted",
            lotNo: lotNo, lotSeq: lotSeq, productId: dashProductId,
            bleIdentifier: "0000-0000")

        podState.setupProgress = .podPaired
        podState.activatedAt = start
        podState.expiresAt = start + .hours(72)

        let fault = mockFault ? try? DetailedStatus(encodedData: Data(hexadecimalString: "020f0000000900345c000103ff0001000005ae056029")!) : nil
        podState.fault = fault

        self.podComms = PodComms(podState: podState, myId: state.controllerId, podId: state.podId)

        setState({ (state) in
            state.podState = podState
            state.expirationReminderDate = start + .hours(70)
        })
    }
    #endif

    // MARK: - Pairing

    func connectToNewPod(completion: @escaping (Result<OmniBLE, Error>) -> Void) {
         podComms.connectToNewPod(completion)
    }

    // Called on the main thread
    public func pairAndPrime(completion: @escaping (PumpManagerResult<TimeInterval>) -> Void) {
        #if targetEnvironment(simulator)
        // If we're in the simulator, create a mock PodState
        let mockFaultDuringPairing = false
        let mockCommsErrorDuringPairing = false
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(2)) {
            self.jumpStartPod(lotNo: 135601809, lotSeq: 0800525, mockFault: mockFaultDuringPairing)
            let fault: DetailedStatus? = self.setStateWithResult({ (state) in
                state.podState?.setupProgress = .priming
                return state.podState?.fault
            })
            if mockFaultDuringPairing {
                completion(.failure(PodCommsError.podFault(fault: fault!)))
            } else if mockCommsErrorDuringPairing {
                completion(.failure(PodCommsError.noResponse))
            } else {
                let mockPrimeDuration = TimeInterval(.seconds(3))
                completion(.success(mockPrimeDuration))
            }
        }
        #else
        let primeSession = { (result: PodComms.SessionRunResult) in
            switch result {
            case .success(let session):
                // We're on the session queue
                session.assertOnSessionQueue()

                self.log.default("Beginning pod prime")

                // Clean up any previously un-stored doses if needed
                let unstoredDoses = self.state.unstoredDoses
                if self.store(doses: unstoredDoses, in: session) {
                    self.setState({ (state) in
                        state.unstoredDoses.removeAll()
                    })
                }

                do {
                    let primeFinishedAt = try session.prime()
                    completion(.success(primeFinishedAt))
                } catch let error {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }

        let needsPairing = setStateWithResult({ (state) -> Bool in
            guard let podState = state.podState else {
                return true // Needs pairing
            }

            // Return true if not yet paired
            return podState.setupProgress.isPaired == false
        })

        if needsPairing {
            self.log.default("Pairing pod before priming")

            connectToNewPod(completion: { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success:
                    self.podComms.pairAndSetupPod(timeZone: .currentFixed, messageLogger: self)
                    { (result) in

                        // Calls completion
                        primeSession(result)
                    }
                }
            })
        } else {
            self.log.default("Pod already paired. Continuing.")

            self.podComms.runSession(withName: "Prime pod") { (result) in
                // Calls completion
                primeSession(result)
            }
        }
        #endif
    }

    // Called on the main thread
    public func insertCannula(completion: @escaping (PumpManagerResult<TimeInterval>) -> Void) {
        #if targetEnvironment(simulator)
        let mockDelay = TimeInterval(seconds: 3)
        let mockFaultDuringInsertCannula = false
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + mockDelay) {
            let result = self.setStateWithResult({ (state) -> PumpManagerResult<TimeInterval> in
                if mockFaultDuringInsertCannula {
                    let fault = try! DetailedStatus(encodedData: Data(hexadecimalString: "020d0000000e00c36a020703ff020900002899080082")!)
                    state.podState?.fault = fault
                    return .failure(PodCommsError.podFault(fault: fault))
                }

                // Mock success
                state.podState?.setupProgress = .completed
                return .success(mockDelay)
            })

            completion(result)
        }
        #else
        let preError = setStateWithResult({ (state) -> OmniBLEPumpManagerError? in
            guard let podState = state.podState, let expiresAt = podState.expiresAt, podState.readyForCannulaInsertion else
            {
                return .notReadyForCannulaInsertion
            }

            state.expirationReminderDate = expiresAt.addingTimeInterval(-Pod.expirationReminderAlertDefaultTimeBeforeExpiration)

            guard podState.setupProgress.needsCannulaInsertion else {
                return .podAlreadyPaired
            }

            return nil
        })

        if let error = preError {
            completion(.failure(error))
            return
        }

        let timeZone = self.state.timeZone

        self.podComms.runSession(withName: "Insert cannula") { (result) in
            switch result {
            case .success(let session):
                do {
                    if self.state.podState?.setupProgress.needsInitialBasalSchedule == true {
                        let scheduleOffset = timeZone.scheduleOffset(forDate: Date())
                        try session.programInitialBasalSchedule(self.state.basalSchedule, scheduleOffset: scheduleOffset)

                        session.dosesForStorage() { (doses) -> Bool in
                            return self.store(doses: doses, in: session)
                        }
                    }

                    let finishWait = try session.insertCannula()
                    completion(.success(finishWait))
                } catch let error {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
        #endif
    }

    public func checkCannulaInsertionFinished(completion: @escaping (Error?) -> Void) {
        self.podComms.runSession(withName: "Check cannula insertion finished") { (result) in
            switch result {
            case .success(let session):
                do {
                    try session.checkInsertionCompleted()
                    completion(nil)
                } catch let error {
                    self.log.error("Failed to fetch pod status: %{public}@", String(describing: error))
                    completion(error)
                }
            case .failure(let error):
                self.log.error("Failed to fetch pod status: %{public}@", String(describing: error))
                completion(error)
            }
        }
    }

    public func refreshStatus(emitConfirmationBeep: Bool = false, completion: ((_ result: PumpManagerResult<StatusResponse>) -> Void)? = nil) {
        guard self.hasActivePod else {
            completion?(.failure(OmniBLEPumpManagerError.noPodPaired))
            return
        }

        self.getPodStatus(storeDosesOnSuccess: false, emitConfirmationBeep: emitConfirmationBeep, completion: completion)
    }

    public func getPodStatus(storeDosesOnSuccess: Bool, emitConfirmationBeep: Bool, completion: ((_ result: PumpManagerResult<StatusResponse>) -> Void)? = nil) {
        guard state.podState?.unfinalizedBolus?.scheduledCertainty == .uncertain || state.podState?.unfinalizedBolus?.isFinished() != false else {
            self.log.info("Skipping status request due to unfinalized bolus in progress.")
            completion?(.failure(PodCommsError.unfinalizedBolus))
            return
        }

        podComms.runSession(withName: "Get pod status") { (result) in
            do {
                switch result {
                case .success(let session):
                    let beepBlock = emitConfirmationBeep ? self.beepMessageBlock(beepType: .bipBip) : nil
                    let status = try session.getStatus(beepBlock: beepBlock)

                    if storeDosesOnSuccess {
                        session.dosesForStorage({ (doses) -> Bool in
                            self.store(doses: doses, in: session)
                        })
                    }
                    completion?(.success(status))
                case .failure(let error):
                    throw error
                }
                self.issueHeartbeatIfNeeded()
            } catch let error {
                completion?(.failure(error))
                self.log.error("Failed to fetch pod status: %{public}@", String(describing: error))
            }
        }
    }

    // MARK: - Pump Commands

    public func acknowledgePodAlerts(_ alertsToAcknowledge: AlertSet, completion: @escaping (_ alerts: [AlertSlot: PodAlert]?) -> Void) {
        guard self.hasActivePod else {
            completion(nil)
            return
        }

        self.podComms.runSession(withName: "Acknowledge Alarms") { (result) in
            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure:
                completion(nil)
                return
            }

            do {
                let beepBlock = self.beepMessageBlock(beepType: .bipBip)
                let alerts = try session.acknowledgePodAlerts(alerts: alertsToAcknowledge, beepBlock: beepBlock)
                completion(alerts)
            } catch {
                completion(nil)
            }
        }
    }

    public func setTime(completion: @escaping (Error?) -> Void) {

        guard state.hasActivePod else {
            completion(OmniBLEPumpManagerError.noPodPaired)
            return
        }

        guard state.podState?.unfinalizedBolus?.isFinished() != false else {
            completion(PodCommsError.unfinalizedBolus)
            return
        }

        let timeZone = TimeZone.currentFixed
        self.podComms.runSession(withName: "Set time zone") { (result) in
            switch result {
            case .success(let session):
                do {
                    let beep = self.confirmationBeeps
                    let _ = try session.setTime(timeZone: timeZone, basalSchedule: self.state.basalSchedule, date: Date(), acknowledgementBeep: beep)
                    self.setState { (state) in
                        state.timeZone = timeZone
                    }
                    completion(nil)
                } catch let error {
                    completion(error)
                }
            case .failure(let error):
                completion(error)
            }
        }
    }

    public func setBasalSchedule(_ schedule: BasalSchedule, completion: @escaping (Error?) -> Void) {
        let shouldContinue = setStateWithResult({ (state) -> PumpManagerResult<Bool> in
            guard state.hasActivePod else {
                // If there's no active pod yet, save the basal schedule anyway
                state.basalSchedule = schedule
                return .success(false)
            }

            guard state.podState?.unfinalizedBolus?.isFinished() != false else {
                return .failure(PodCommsError.unfinalizedBolus)
            }

            return .success(true)
        })

        switch shouldContinue {
        case .success(true):
            break
        case .success(false):
            completion(nil)
            return
        case .failure(let error):
            completion(error)
            return
        }

        let timeZone = self.state.timeZone

        self.podComms.runSession(withName: "Save Basal Profile") { (result) in
            do {
                switch result {
                case .success(let session):
                    let scheduleOffset = timeZone.scheduleOffset(forDate: Date())
                    let result = session.cancelDelivery(deliveryType: .all)
                    switch result {
                    case .certainFailure(let error):
                        throw error
                    case .unacknowledged(let error):
                        throw error
                    case .success:
                        break
                    }
                    let beep = self.confirmationBeeps
                    let _ = try session.setBasalSchedule(schedule: schedule, scheduleOffset: scheduleOffset, acknowledgementBeep: beep)

                    self.setState { (state) in
                        state.basalSchedule = schedule
                    }
                    completion(nil)
                case .failure(let error):
                    throw error
                }
            } catch let error {
                self.log.error("Save basal profile failed: %{public}@", String(describing: error))
                completion(error)
            }
        }
    }

    // Called on the main thread.
    // The UI is responsible for serializing calls to this method;
    // it does not handle concurrent calls.
    public func deactivatePod(forgetPodOnFail: Bool, completion: @escaping (Error?) -> Void) {
        #if targetEnvironment(simulator)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(2)) {

            self.forgetPod(completion: {
                completion(nil)
            })
        }
        #else
        guard self.state.podState != nil else {
            if forgetPodOnFail {
                forgetPod(completion: {
                    completion(OmniBLEPumpManagerError.noPodPaired)
                })
            } else {
                completion(OmniBLEPumpManagerError.noPodPaired)
            }
            return
        }

        self.podComms.runSession(withName: "Deactivate pod") { (result) in
            switch result {
            case .success(let session):
                do {
                    try session.deactivatePod()

                    self.forgetPod(completion: {
                        completion(nil)
                    })
                } catch let error {
                    if forgetPodOnFail {
                        self.forgetPod(completion: {
                            completion(error)
                        })
                    } else {
                        completion(error)
                    }
                }
            case .failure(let error):
                if forgetPodOnFail {
                    self.forgetPod(completion: {
                        completion(error)
                    })
                } else {
                    completion(error)
                }
            }
        }
        #endif
    }

    public func readPodStatus(completion: @escaping (Result<DetailedStatus, Error>) -> Void) {
        // use hasSetupPod to be able to read pod info from a faulted Pod
        guard self.hasSetupPod else {
            completion(.failure(OmniBLEPumpManagerError.noPodPaired))
            return
        }

        podComms.runSession(withName: "Read pod status") { (result) in
            do {
                switch result {
                case .success(let session):
                    let beepBlock = self.beepMessageBlock(beepType: .bipBip)
                    let detailedStatus = try session.getDetailedStatus(beepBlock: beepBlock)
                    session.dosesForStorage({ (doses) -> Bool in
                        self.store(doses: doses, in: session)
                    })
                    completion(.success(detailedStatus))
                case .failure(let error):
                    completion(.failure(error))
                }
            } catch let error {
                completion(.failure(error))
            }
        }
    }

    public func testingCommands(completion: @escaping (Error?) -> Void) {
        // use hasSetupPod so the user can see any fault info and post fault commands can be attempted
        guard self.hasSetupPod else {
            completion(OmniBLEPumpManagerError.noPodPaired)
            return
        }

        self.podComms.runSession(withName: "Testing Commands") { (result) in
            switch result {
            case .success(let session):
                do {
                    let beepBlock = self.beepMessageBlock(beepType: .beepBeepBeep)
                    try session.testingCommands(beepBlock: beepBlock)
                    completion(nil)
                } catch let error {
                    completion(error)
                }
            case .failure(let error):
                completion(error)
            }
        }
    }

    public func playTestBeeps(completion: @escaping (Error?) -> Void) {
        guard self.hasActivePod else {
            completion(OmniBLEPumpManagerError.noPodPaired)
            return
        }
        guard state.podState?.unfinalizedBolus?.scheduledCertainty == .uncertain || state.podState?.unfinalizedBolus?.isFinished() != false else {
            self.log.info("Skipping Play Test Beeps due to bolus still in progress.")
            completion(PodCommsError.unfinalizedBolus)
            return
        }

        self.podComms.runSession(withName: "Play Test Beeps") { (result) in
            switch result {
            case .success(let session):
                let beep = self.confirmationBeeps
                let result = session.beepConfig(
                    beepConfigType: .bipBeepBipBeepBipBeepBipBeep,
                    tempBasalCompletionBeep: beep && self.hasUnfinalizedManualTempBasal,
                    bolusCompletionBeep: beep && self.hasUnfinalizedManualBolus
                )

                switch result {
                case .success:
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            case .failure(let error):
                completion(error)
            }
        }
    }

    public func readPulseLog(completion: @escaping (Result<String, Error>) -> Void) {
        // use hasSetupPod to be able to read pulse log from a faulted Pod
        guard self.hasSetupPod else {
            completion(.failure(OmniBLEPumpManagerError.noPodPaired))
            return
        }
        guard state.podState?.isFaulted == true || state.podState?.unfinalizedBolus?.scheduledCertainty == .uncertain || state.podState?.unfinalizedBolus?.isFinished() != false else
        {
            self.log.info("Skipping Read Pulse Log due to bolus still in progress.")
            completion(.failure(PodCommsError.unfinalizedBolus))
            return
        }

        self.podComms.runSession(withName: "Read Pulse Log") { (result) in
            switch result {
            case .success(let session):
                do {
                    // read the most recent 50 entries from the pulse log
                    let beepBlock = self.beepMessageBlock(beepType: .bipBeeeeep)
                    let podInfoResponse = try session.readPodInfo(podInfoResponseSubType: .pulseLogRecent, beepBlock: beepBlock)
                    guard let podInfoPulseLogRecent = podInfoResponse.podInfo as? PodInfoPulseLogRecent else {
                        self.log.error("Unable to decode PulseLogRecent: %s", String(describing: podInfoResponse))
                        completion(.failure(PodCommsError.unexpectedResponse(response: .podInfoResponse)))
                        return
                    }
                    let lastPulseNumber = Int(podInfoPulseLogRecent.indexLastEntry)
                    let str = pulseLogString(pulseLogEntries: podInfoPulseLogRecent.pulseLog, lastPulseNumber: lastPulseNumber)
                    completion(.success(str))
                } catch let error {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func setConfirmationBeeps(enabled: Bool, completion: @escaping (Error?) -> Void) {
        self.log.default("Set Confirmation Beeps to %s", String(describing: enabled))
        guard self.hasActivePod else {
            self.confirmationBeeps = enabled // set here to allow changes on a faulted Pod
            completion(nil)
            return
        }

        let name: String = enabled ? "Enable Confirmation Beeps" : "Disable Confirmation Beeps"
        self.podComms.runSession(withName: name) { (result) in
            switch result {
            case .success(let session):
                let beepConfigType: BeepConfigType = enabled ? .bipBip : .noBeep
                let tempBasalCompletionBeep = enabled && self.hasUnfinalizedManualTempBasal
                let bolusCompletionBeep = enabled && self.hasUnfinalizedManualBolus

                // enable/disable Pod completion beeps for any in-progress insulin delivery
                let result = session.beepConfig(beepConfigType: beepConfigType, tempBasalCompletionBeep: tempBasalCompletionBeep, bolusCompletionBeep: bolusCompletionBeep)

                switch result {
                case .success:
                    self.confirmationBeeps = enabled
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            case .failure(let error):
                completion(error)
            }
        }
    }
}

// MARK: - PumpManager
extension OmniBLEPumpManager: PumpManager {

    public static let managerIdentifier: String = "Omnipod-Dash" // use a single token to make parsing log files easier

    public static let localizedTitle = LocalizedString("Omnipod Dash", comment: "User friendly title of the OmniBLE pump manager")

    public var supportedBolusVolumes: [Double] {
        // 0.05 units for rates between 0.05-30U/hr
        // 0 is not a supported bolus volume
        return (1...600).map { Double($0) / Double(Pod.pulsesPerUnit) }
    }

    public var supportedBasalRates: [Double] {
        // 0.05 units for rates between 0.00-30U/hr
        // 0 U/hr is a supported scheduled basal rate for Dash, but not for Eros
        return (0...600).map { Double($0) / Double(Pod.pulsesPerUnit) }
    }

    public func roundToSupportedBolusVolume(units: Double) -> Double {
        // We do support rounding a 0 U volume to 0
        return supportedBolusVolumes.last(where: { $0 <= units }) ?? 0
    }

    public func roundToSupportedBasalRate(unitsPerHour: Double) -> Double {
        // We do support rounding a 0 U/hr rate to 0
        return supportedBasalRates.last(where: { $0 <= unitsPerHour }) ?? 0
    }

    public var maximumBasalScheduleEntryCount: Int {
        return Pod.maximumBasalScheduleEntryCount
    }

    public var minimumBasalScheduleEntryDuration: TimeInterval {
        return Pod.minimumBasalScheduleEntryDuration
    }

    public var pumpRecordsBasalProfileStartEvents: Bool {
        return false
    }

    public var pumpReservoirCapacity: Double {
        return Pod.reservoirCapacity
    }

    public var lastReconciliation: Date? {
        return self.state.podState?.lastInsulinMeasurements?.validTime
    }

    public var status: PumpManagerStatus {
        // Acquire the lock just once
        let state = self.state

        return status(for: state)
    }

    public var rawState: PumpManager.RawStateValue {
        return state.rawValue
    }

    public var pumpManagerDelegate: PumpManagerDelegate? {
        get {
            return pumpDelegate.delegate
        }
        set {
            pumpDelegate.delegate = newValue

            // TODO: is there still a scenario where this is required?
            // self.schedulePodExpirationNotification()
        }
    }

    public var delegateQueue: DispatchQueue! {
        get {
            return pumpDelegate.queue
        }
        set {
            pumpDelegate.queue = newValue
        }
    }

    // MARK: Methods

    public func suspendDelivery(completion: @escaping (Error?) -> Void) {
        let suspendTime: TimeInterval = .minutes(0) // untimed suspend with reminder beeps
        suspendDelivery(withSuspendReminders: suspendTime, completion: completion)
    }

    // A nil suspendReminder is untimed with no reminders beeps, a suspendReminder of 0 is untimed using reminders beeps, otherwise it
    // specifies a suspend duration implemented using an appropriate combination of suspended reminder and suspend time expired beeps.
    public func suspendDelivery(withSuspendReminders suspendReminder: TimeInterval? = nil, completion: @escaping (Error?) -> Void) {
        guard self.hasActivePod else {
            completion(OmniBLEPumpManagerError.noPodPaired)
            return
        }

        self.podComms.runSession(withName: "Suspend") { (result) in

            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure(let error):
                completion(error)
                return
            }

            defer {
                self.setState({ (state) in
                    state.suspendEngageState = .stable
                })
            }
            self.setState({ (state) in
                state.suspendEngageState = .engaging
            })

            // Use a beepBlock for the confirmation beep to avoid getting 3 beeps using cancel command beeps!
            let beepBlock = self.beepMessageBlock(beepType: .beeeeeep)
            let result = session.suspendDelivery(suspendReminder: suspendReminder, beepBlock: beepBlock)
            switch result {
            case .certainFailure(let error):
                completion(error)
            case .unacknowledged(let error):
                completion(error)
            case .success:
                session.dosesForStorage() { (doses) -> Bool in
                    return self.store(doses: doses, in: session)
                }
                completion(nil)
            }
        }
    }

    public func resumeDelivery(completion: @escaping (Error?) -> Void) {
        guard self.hasActivePod else {
            completion(OmniBLEPumpManagerError.noPodPaired)
            return
        }

        self.podComms.runSession(withName: "Resume") { (result) in

            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure(let error):
                completion(error)
                return
            }

            defer {
                self.setState({ (state) in
                    state.suspendEngageState = .stable
                })
            }
            self.setState({ (state) in
                state.suspendEngageState = .disengaging
            })

            do {
                let scheduleOffset = self.state.timeZone.scheduleOffset(forDate: Date())
                let beep = self.confirmationBeeps
                let _ = try session.resumeBasal(schedule: self.state.basalSchedule, scheduleOffset: scheduleOffset, acknowledgementBeep: beep)
                session.dosesForStorage() { (doses) -> Bool in
                    return self.store(doses: doses, in: session)
                }
                completion(nil)
            } catch (let error) {
                completion(error)
            }
        }
    }

    public func addStatusObserver(_ observer: PumpManagerStatusObserver, queue: DispatchQueue) {
        statusObservers.insert(observer, queue: queue)
    }

    public func removeStatusObserver(_ observer: PumpManagerStatusObserver) {
        statusObservers.removeElement(observer)
    }

    // Called only from pumpDelegate notify block
    private func recommendLoopIfNeeded(_ delegate: PumpManagerDelegate?) {
        if lastLoopRecommendation == nil || lastLoopRecommendation!.timeIntervalSinceNow < .minutes(-4.5) {
            self.log.default("Recommending Loop")
            lastLoopRecommendation = Date()
            delegate?.pumpManagerRecommendsLoop(self)
        }
    }

    public func assertCurrentPumpData() {
        let shouldFetchStatus = setStateWithResult { (state) -> Bool? in
            guard state.hasActivePod else {
                return nil // No active pod
            }

            return state.isPumpDataStale
        }

        switch shouldFetchStatus {
        case .none:
            return // No active pod
        case true?:
            log.default("Fetching status because pumpData is too old")
            getPodStatus(storeDosesOnSuccess: true, emitConfirmationBeep: false) { (response) in
                self.pumpDelegate.notify({ (delegate) in
                    switch response {
                    case .success:
                        self.recommendLoopIfNeeded(delegate)
                    case .failure(let error):
                        self.log.default("Not recommending Loop because pump data is stale: %@", String(describing: error))
                        if let error = error as? PumpManagerError {
                            delegate?.pumpManager(self, didError: error)
                        }
                    }
                })
            }
        case false?:
            log.default("Skipping status update because pumpData is fresh")
            pumpDelegate.notify { (delegate) in
                self.recommendLoopIfNeeded(delegate)
            }
        }
    }

    public func enactBolus(units: Double, at startDate: Date, automatic: Bool, willRequest: @escaping (DoseEntry) -> Void, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        guard self.hasActivePod else {
            completion(.failure(SetBolusError.certain(OmniBLEPumpManagerError.noPodPaired)))
            return
        }

        // Round to nearest supported volume
        let enactUnits = roundToSupportedBolusVolume(units: units)

        self.podComms.runSession(withName: "Bolus") { (result) in
            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure(let error):
                completion(.failure(SetBolusError.certain(error)))
                return
            }

            defer {
                self.setState({ (state) in
                    state.bolusEngageState = .stable
                })
            }
            self.setState({ (state) in
                state.bolusEngageState = .engaging
            })

            // Match existing Medtronic auto resume PumpManager behavior (limited to manual boluses as a safeguard)
            let autoResumeOnManualBolus = true

            if case .some(.suspended) = self.state.podState?.suspendState {
                // Pod suspended, only auto resume for a manual bolus if autoResumeOnManualBolus is true
                if automatic || !autoResumeOnManualBolus {
                    self.log.error("enactBolus: returning pod suspended error for %@ bolus", automatic ? "automatic" : "manual")
                    completion(.failure(SetBolusError.certain(PodCommsError.podSuspended)))
                    return
                }
                do {
                    let scheduleOffset = self.state.timeZone.scheduleOffset(forDate: Date())
                    let beep = self.confirmationBeeps
                    let podStatus = try session.resumeBasal(schedule: self.state.basalSchedule, scheduleOffset: scheduleOffset, acknowledgementBeep: beep)
                    guard !podStatus.deliveryStatus.bolusing else {
                        throw SetBolusError.certain(PodCommsError.unfinalizedBolus)
                    }
                } catch let error {
                    completion(.failure(SetBolusError.certain(error as? PodCommsError ?? PodCommsError.commsError(error: error))))
                    return
                }
            }

            var getStatusNeeded = false
            var finalizeFinishedDosesNeeded = false

            // Skip the getStatus comms optimization for a manual bolus,
            // if there was a comms issue on the last message sent, or
            // if the last delivery status hasn't been verified OK
            if !automatic || self.state.podState?.lastCommsOK == false ||
                self.state.podState?.deliveryStatusVerified == false
            {
                self.log.info("enactBolus: skipping getStatus comms optimization")
                getStatusNeeded = true
            } else if let unfinalizedBolus = self.state.podState?.unfinalizedBolus {
                if unfinalizedBolus.scheduledCertainty == .uncertain {
                    self.log.info("enactBolus: doing getStatus with uncertain bolus scheduled certainty")
                    getStatusNeeded = true
                } else if !unfinalizedBolus.isFinished() {
                     completion(.failure(SetBolusError.certain(PodCommsError.unfinalizedBolus)))
                     return
                } else if !unfinalizedBolus.isBolusPositivelyFinished() {
                    getStatusNeeded = true // do getStatus to verify if bolus has actually completed
                } else {
                    finalizeFinishedDosesNeeded = true // call finalizeFinishDoses() to clean up the certain & positively finalized bolus
                }
            }

            if getStatusNeeded {
                do {
                    let podStatus = try session.getStatus()
                    guard !podStatus.deliveryStatus.bolusing else {
                        completion(.failure(SetBolusError.certain(PodCommsError.unfinalizedBolus)))
                        return
                    }
                } catch let error {
                    completion(.failure(SetBolusError.certain(error as? PodCommsError ?? PodCommsError.commsError(error: error))))
                    return
                }
            } else if finalizeFinishedDosesNeeded {
                session.finalizeFinishedDoses()
            }

            let date = Date()
            let endDate = date.addingTimeInterval(enactUnits / Pod.bolusDeliveryRate)
            let dose = DoseEntry(type: .bolus, startDate: date, endDate: endDate, value: enactUnits, unit: .units)
            willRequest(dose)

            let acknowledgementBeep = automatic ? self.shouldBeepForAutomaticBolus : self.confirmationBeeps
            let completionBeep = self.confirmationBeeps && !automatic

            // Use bits for the otherwise unused program reminder interval to indicate if this bolus was automatic
            // to allow determination using the device logs whether a bolus was initiated by the user or the app.
            // The maximum possible "reminder" value of 0x3F (63 minutes) is used which is well beyond the longest
            // possible time for an immediate bolus and thus can never result in any pod program reminder beeps.
            let bolusWasAutomaticIndicator: TimeInterval = automatic ? TimeInterval(minutes: 0x3F) : 0

            let result = session.bolus(units: enactUnits, automatic: automatic, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep, programReminderInterval: bolusWasAutomaticIndicator)
            session.dosesForStorage() { (doses) -> Bool in
                return self.store(doses: doses, in: session)
            }

            switch result {
            case .success:
                completion(.success(dose))
            case .certainFailure(let error):
                completion(.failure(SetBolusError.certain(error)))
            case .unacknowledged(let error):
                completion(.failure(SetBolusError.uncertain(error)))
            }
        }
    }

    public func cancelBolus(completion: @escaping (PumpManagerResult<DoseEntry?>) -> Void) {
        guard self.hasActivePod else {
            completion(.failure(OmniBLEPumpManagerError.noPodPaired))
            return
        }

        self.podComms.runSession(withName: "Cancel Bolus") { (result) in

            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure(let error):
                completion(.failure(error))
                return
            }

            do {
                defer {
                    self.setState({ (state) in
                        state.bolusEngageState = .stable
                    })
                }
                self.setState({ (state) in
                    state.bolusEngageState = .disengaging
                })

                if let bolus = self.state.podState?.unfinalizedBolus, !bolus.isFinished(), bolus.scheduledCertainty == .uncertain {
                    let status = try session.getStatus()

                    if !status.deliveryStatus.bolusing {
                        completion(.success(nil))
                        return
                    }
                }

                // when cancelling a bolus use the built-in type 6 beeeeeep to match PDM if confirmation beeps are enabled
                let beeptype: BeepType = self.confirmationBeeps ? .beeeeeep : .noBeep
                let result = session.cancelDelivery(deliveryType: .bolus, beepType: beeptype)
                switch result {
                case .certainFailure(let error):
                    throw error
                case .unacknowledged(let error):
                    throw error
                case .success(_, let canceledBolus):
                    session.dosesForStorage() { (doses) -> Bool in
                        return self.store(doses: doses, in: session)
                    }

                    let canceledDoseEntry: DoseEntry? = canceledBolus != nil ? DoseEntry(canceledBolus!) : nil
                    completion(.success(canceledDoseEntry))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, automatic: Bool, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        guard self.hasActivePod else {
            completion(.failure(OmniBLEPumpManagerError.noPodPaired))
            return
        }

        // Round to nearest supported rate
        let rate = roundToSupportedBasalRate(unitsPerHour: unitsPerHour)

        let acknowledgementBeep = automatic ? shouldBeepForAutomaticTempBasal : confirmationBeeps
        let completionBeep = confirmationBeeps && !automatic

        self.podComms.runSession(withName: "Enact Temp Basal") { (result) in
            self.log.info("Enact temp basal %.03fU/hr for %ds", rate, Int(duration))
            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure(let error):
                completion(.failure(error))
                return
            }

            do {
                if case .some(.suspended) = self.state.podState?.suspendState {
                    self.log.info("Not enacting temp basal because podState indicates pod is suspended.")
                    throw PodCommsError.podSuspended
                }

                guard self.state.podState?.unfinalizedBolus?.isFinished() != false else {
                    self.log.info("Not enacting temp basal because podState indicates unfinalized bolus in progress.")
                    throw PodCommsError.unfinalizedBolus
                }

                // A resume scheduled basal delivery request is denoted by a 0 duration that cancels any existing temp basal.
                let resumingScheduledBasal = duration < .ulpOfOne

                // Did the last message have comms issues or is the last delivery status not yet verified?
                let uncertainDeliveryStatus = self.state.podState?.lastCommsOK == false ||
                                                self.state.podState?.deliveryStatusVerified == false

                // Do the cancel temp basal command if currently running a temp basal OR
                // if resuming scheduled basal delivery OR if the delivery status is uncertain.
                var canceledDose: UnfinalizedDose? = nil
                if self.state.podState?.unfinalizedTempBasal != nil || resumingScheduledBasal || uncertainDeliveryStatus {
                    let status: StatusResponse

                    // if resuming scheduled basal delivery & an acknowledgement beep is needed, use the cancel TB beep
                    let beepType: BeepType = resumingScheduledBasal && acknowledgementBeep ? .beep : .noBeep
                    let result = session.cancelDelivery(deliveryType: .tempBasal, beepType: beepType)
                    switch result {
                    case .certainFailure(let error):
                        throw error
                    case .unacknowledged(let error):
                        // TODO: Return PumpManagerError.uncertainDelivery and implement recovery if resumingNormalBasal
                        throw error
                    case .success(let cancelTempStatus, let dose):
                        status = cancelTempStatus
                        canceledDose = dose
                    }

                    guard !status.deliveryStatus.bolusing else {
                        throw PodCommsError.unfinalizedBolus
                    }

                    guard status.deliveryStatus != .suspended else {
                        self.log.info("Canceling temp basal because status return indicates pod is suspended!")
                        throw PodCommsError.podSuspended
                    }
                } else {
                    self.log.info("Skipped Cancel TB command before enacting temp basal")
                }

                defer {
                    self.setState({ (state) in
                        state.tempBasalEngageState = .stable
                    })
                }

                if resumingScheduledBasal {
                    self.setState({ (state) in
                        state.tempBasalEngageState = .disengaging
                    })
                    let cancelTime = canceledDose?.finishTime ?? Date()
                    let dose = DoseEntry(type: .tempBasal, startDate: cancelTime, endDate: cancelTime, value: 0, unit: .unitsPerHour)
                    session.dosesForStorage() { (doses) -> Bool in
                        return self.store(doses: doses, in: session)
                    }
                    completion(.success(dose))
                } else {
                    self.setState({ (state) in
                        state.tempBasalEngageState = .engaging
                    })

                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = self.state.timeZone
                    let scheduledRate = self.state.basalSchedule.currentRate(using: calendar, at: Date())
                    let isHighTemp = rate > scheduledRate

                    let result = session.setTempBasal(rate: rate, duration: duration, automatic: automatic, isHighTemp: isHighTemp, acknowledgementBeep: acknowledgementBeep, completionBeep: completionBeep)
                    let basalStart = Date()
                    let dose = DoseEntry(type: .tempBasal, startDate: basalStart, endDate: basalStart.addingTimeInterval(duration), value: rate, unit: .unitsPerHour)
                    session.dosesForStorage() { (doses) -> Bool in
                        return self.store(doses: doses, in: session)
                    }
                    switch result {
                    case .success:
                        completion(.success(dose))
                    case .unacknowledged(let error):
                        // TODO: Return PumpManagerError.uncertainDelivery and implement recovery
                        self.log.error("Temp basal uncertain error: %@", String(describing: error))
                        completion(.success(dose))
                    case .certainFailure(let error):
                        throw error
                    }
                }
            } catch let error {
                self.log.error("Error during temp basal: %@", String(describing: error))
                completion(.failure(error))
            }
        }
    }

    /// Returns a dose estimator for the current bolus, if one is in progress
    public func createBolusProgressReporter(reportingOn dispatchQueue: DispatchQueue) -> DoseProgressReporter? {
        if case .inProgress(let dose) = bolusState(for: self.state) {
            return PodDoseProgressEstimator(dose: dose, pumpManager: self, reportingQueue: dispatchQueue)
        }
        return nil
    }

    // This cannot be called from within the lockedState lock!
    func store(doses: [UnfinalizedDose], in session: PodCommsSession) -> Bool {
        session.assertOnSessionQueue()

        // We block the session until the data's confirmed stored by the delegate
        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        store(doses: doses) { (error) in
            success = (error == nil)
            semaphore.signal()
        }

        semaphore.wait()

        if success {
            setState { (state) in
                state.lastPumpDataReportDate = Date()
            }
        }
        return success
    }

    func store(doses: [UnfinalizedDose], completion: @escaping (_ error: Error?) -> Void) {
        let lastPumpReconciliation = lastReconciliation

        pumpDelegate.notify { (delegate) in
            guard let delegate = delegate else {
                preconditionFailure("pumpManagerDelegate cannot be nil")
            }

            delegate.pumpManager(self, hasNewPumpEvents: doses.map { NewPumpEvent($0) }, lastReconciliation: lastPumpReconciliation, completion: { (error) in
                if let error = error {
                    self.log.error("Error storing pod events: %@", String(describing: error))
                } else {
                    self.log.info("DU: Stored pod events: %@", String(describing: doses))
                }

                completion(error)
            })
        }
    }
}

extension OmniBLEPumpManager: MessageLogger {
    func didSend(_ message: Data) {
        log.default("didSend: %{public}@", message.hexadecimalString)
        self.logDeviceCommunication(message.hexadecimalString, type: .send)
    }

    func didReceive(_ message: Data) {
        log.default("didReceive: %{public}@", message.hexadecimalString)
        self.logDeviceCommunication(message.hexadecimalString, type: .receive)
    }
}

extension OmniBLEPumpManager: PodCommsDelegate {

    func podCommsDidEstablishSession(_ podComms: PodComms) {

        podComms.runSession(withName: "Post-connect status fetch") { result in
            switch result {
            case .success(let session):
                let _ = try? session.getStatus()
                session.dosesForStorage() { (doses) -> Bool in
                    return self.store(doses: doses, in: session)
                }
                self.issueHeartbeatIfNeeded()
            case .failure:
                // Errors can be ignored here.
                break
            }
        }

    }

    func podComms(_ podComms: PodComms, didChange podState: PodState) {
        setState { (state) in
            // Check for any updates to bolus certainty, and log them
            if let bolus = state.podState?.unfinalizedBolus, bolus.scheduledCertainty == .uncertain, !bolus.isFinished() {
                if podState.unfinalizedBolus?.scheduledCertainty == .some(.certain) {
                    self.log.default("Resolved bolus uncertainty: did bolus")
                } else if podState.unfinalizedBolus == nil {
                    self.log.default("Resolved bolus uncertainty: did not bolus")
                }
            }
            state.podState = podState
        }
    }
}
