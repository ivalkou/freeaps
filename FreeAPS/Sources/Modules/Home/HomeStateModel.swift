import Combine
import LoopKitUI
import SwiftDate
import SwiftUI

extension Home {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var broadcaster: Broadcaster!
        @Injected() var apsManager: APSManager!
        @Injected() var nightscoutManager: NightscoutManager!
        private let timer = DispatchTimer(timeInterval: 5)
        private(set) var filteredHours = 24

        @Published var glucose: [BloodGlucose] = []
        @Published var suggestion: Suggestion?
        @Published var enactedSuggestion: Suggestion?
        @Published var recentGlucose: BloodGlucose?
        @Published var glucoseDelta: Int?
        @Published var tempBasals: [PumpHistoryEvent] = []
        @Published var boluses: [PumpHistoryEvent] = []
        @Published var suspensions: [PumpHistoryEvent] = []
        @Published var maxBasal: Decimal = 2
        @Published var autotunedBasalProfile: [BasalProfileEntry] = []
        @Published var basalProfile: [BasalProfileEntry] = []
        @Published var tempTargets: [TempTarget] = []
        @Published var displayedTempTargets: [TempTarget] = []

        @Published var carbs: [CarbsEntry] = []
        @Published var timerDate = Date()
        @Published var closedLoop = false
        @Published var pumpSuspended = false
        @Published var isLooping = false
        @Published var statusTitle = ""
        @Published var lastLoopDate: Date = .distantPast
        @Published var tempRate: Decimal?
        @Published var battery: Battery?
        @Published var reservoir: Decimal?
        @Published var pumpName = ""
        @Published var pumpExpiresAtDate: Date?
        @Published var tempTarget: TempTarget?
        @Published var setupPump = false
        @Published var errorMessage: String? = nil
        @Published var errorDate: Date? = nil
        @Published var bolusProgress: Decimal?
        @Published var eventualBG: Int?
        @Published var carbsRequired: Decimal?
        @Published var allowManualTemp = false
        @Published var units: GlucoseUnits = .mmolL
        @Published var pumpDisplayState: PumpDisplayState?
        @Published var alarm: GlucoseAlarm?
        @Published var animatedBackground = false

        override func subscribe() {
            setupGlucose()
            setupBasals()
            setupBoluses()
            setupSuspensions()
            setupPumpSettings()
            setupBasalProfile()
            setupTempTargets()
            setupCarbs()
            setupBattery()
            setupReservoir()

            suggestion = provider.suggestion
            enactedSuggestion = provider.enactedSuggestion
            units = settingsManager.settings.units
            allowManualTemp = !settingsManager.settings.closedLoop
            closedLoop = settingsManager.settings.closedLoop
            lastLoopDate = apsManager.lastLoopDate
            carbsRequired = suggestion?.carbsReq
            alarm = provider.glucoseStorage.alarm

            setStatusTitle()
            setupCurrentTempTarget()

            broadcaster.register(GlucoseObserver.self, observer: self)
            broadcaster.register(SuggestionObserver.self, observer: self)
            broadcaster.register(SettingsObserver.self, observer: self)
            broadcaster.register(PumpHistoryObserver.self, observer: self)
            broadcaster.register(PumpSettingsObserver.self, observer: self)
            broadcaster.register(BasalProfileObserver.self, observer: self)
            broadcaster.register(TempTargetsObserver.self, observer: self)
            broadcaster.register(CarbsObserver.self, observer: self)
            broadcaster.register(EnactedSuggestionObserver.self, observer: self)
            broadcaster.register(PumpBatteryObserver.self, observer: self)
            broadcaster.register(PumpReservoirObserver.self, observer: self)

            animatedBackground = settingsManager.settings.animatedBackground

            timer.eventHandler = {
                DispatchQueue.main.async { [weak self] in
                    self?.timerDate = Date()
                    self?.setupCurrentTempTarget()
                }
            }
            timer.resume()

            apsManager.isLooping
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.isLooping, on: self)
                .store(in: &lifetime)

            apsManager.lastLoopDateSubject
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.lastLoopDate, on: self)
                .store(in: &lifetime)

            apsManager.pumpName
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.pumpName, on: self)
                .store(in: &lifetime)

            apsManager.pumpExpiresAtDate
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.pumpExpiresAtDate, on: self)
                .store(in: &lifetime)

            apsManager.lastError
                .receive(on: DispatchQueue.main)
                .map { [weak self] error in
                    self?.errorDate = error == nil ? nil : Date()
                    if let error = error {
                        info(.default, error.localizedDescription)
                    }
                    return error?.localizedDescription
                }
                .weakAssign(to: \.errorMessage, on: self)
                .store(in: &lifetime)

            apsManager.bolusProgress
                .receive(on: DispatchQueue.main)
                .weakAssign(to: \.bolusProgress, on: self)
                .store(in: &lifetime)

            apsManager.pumpDisplayState
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    guard let self = self else { return }
                    self.pumpDisplayState = state
                    if state == nil {
                        self.reservoir = nil
                        self.battery = nil
                        self.pumpName = ""
                        self.pumpExpiresAtDate = nil
                        self.setupPump = false
                    } else {
                        self.setupBattery()
                        self.setupReservoir()
                    }
                }
                .store(in: &lifetime)

            $tempTargets
                .sink { [weak self] _ in
                    self?.calculateDisplayedTempTargets()
                }
                .store(in: &lifetime)

            $setupPump
                .removeDuplicates()
                .sink { [weak self] show in
                    guard let self = self else { return }
                    if show, let pumpManager = self.provider.apsManager.pumpManager {
                        let view = PumpConfig.PumpSettingsView(pumpManager: pumpManager, completionDelegate: self).asAny()
                        self.router.mainSecondaryModalView.value = view
                    } else {
                        self.router.mainSecondaryModalView.value = nil
                    }
                }
                .store(in: &lifetime)
        }

        func addCarbs() {
            showModal(for: .addCarbs)
        }

        func runLoop() {
            provider.heartbeatNow()
        }

        func cancelBolus() {
            apsManager.cancelBolus()
        }

        private func setupGlucose() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.glucose = self.provider.filteredGlucose(hours: self.filteredHours)
                self.recentGlucose = self.glucose.last
                if self.glucose.count >= 2 {
                    self.glucoseDelta = (self.recentGlucose?.glucose ?? 0) - (self.glucose[self.glucose.count - 2].glucose ?? 0)
                } else {
                    self.glucoseDelta = nil
                }
                self.alarm = self.provider.glucoseStorage.alarm
            }
        }

        private func setupBasals() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.tempBasals = self.provider.pumpHistory(hours: self.filteredHours).filter {
                    $0.type == .tempBasal || $0.type == .tempBasalDuration
                }
                let lastTempBasal = Array(self.tempBasals.suffix(2))
                guard lastTempBasal.count == 2 else {
                    self.tempRate = nil
                    return
                }

                guard let lastRate = lastTempBasal[0].rate, let lastDuration = lastTempBasal[1].durationMin else {
                    self.tempRate = nil
                    return
                }
                let lastDate = lastTempBasal[0].timestamp
                guard Date().timeIntervalSince(lastDate.addingTimeInterval(lastDuration.minutes.timeInterval)) < 0 else {
                    self.tempRate = nil
                    return
                }
                self.tempRate = lastRate
            }
        }

        private func setupBoluses() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.boluses = self.provider.pumpHistory(hours: self.filteredHours).filter {
                    $0.type == .bolus
                }
            }
        }

        private func setupSuspensions() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.suspensions = self.provider.pumpHistory(hours: self.filteredHours).filter {
                    $0.type == .pumpSuspend || $0.type == .pumpResume
                }

                let last = self.suspensions.last
                let tbr = self.tempBasals.first { $0.timestamp > (last?.timestamp ?? .distantPast) }

                self.pumpSuspended = tbr == nil && last?.type == .pumpSuspend
            }
        }

        private func setupPumpSettings() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.maxBasal = self.provider.pumpSettings().maxBasal
            }
        }

        private func setupBasalProfile() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.autotunedBasalProfile = self.provider.autotunedBasalProfile()
                self.basalProfile = self.provider.basalProfile()
            }
        }

        private func setupTempTargets() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.tempTargets = self.provider.tempTargets(hours: self.filteredHours)
            }
        }

        private func setupCarbs() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.carbs = self.provider.carbs(hours: self.filteredHours)
            }
        }

        private func setStatusTitle() {
            guard let suggestion = suggestion else {
                statusTitle = "No suggestion"
                return
            }

            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            if closedLoop,
               let enactedSuggestion = enactedSuggestion,
               let timestamp = enactedSuggestion.timestamp,
               enactedSuggestion.deliverAt == suggestion.deliverAt, enactedSuggestion.recieved == true
            {
                statusTitle = "Enacted at \(dateFormatter.string(from: timestamp))"
            } else if let suggestedDate = suggestion.deliverAt {
                statusTitle = "Suggested at \(dateFormatter.string(from: suggestedDate))"
            } else {
                statusTitle = "Suggested"
            }

            eventualBG = suggestion.eventualBG
        }

        private func setupReservoir() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.reservoir = self.provider.pumpReservoir()
            }
        }

        private func setupBattery() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.battery = self.provider.pumpBattery()
            }
        }

        private func setupCurrentTempTarget() {
            tempTarget = provider.tempTarget()
        }

        private func calculateDisplayedTempTargets() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // get cancel items from all temptargets
                let cancelDates: [Date] = self.tempTargets
                    .filter {
                        $0.duration == 0
                    }.sorted {
                        $0.createdAt > $1.createdAt
                    }.map(\.createdAt)

                var resultTempTargets: [TempTarget] = []

                // slice temp targets by cancel items and others temp targets
                self.tempTargets
                    .filter {
                        $0.duration > 0
                    }.sorted {
                        $0.createdAt > $1.createdAt
                    }.map { tempTarget -> TempTarget in
                        let sourceFinishDate = self.getFinishDateOf(tempTarget)
                        let calculateFinishDate = cancelDates.first(where: { cancelItem in
                            tempTarget.createdAt < cancelItem && sourceFinishDate > cancelItem
                        }) ?? sourceFinishDate
                        let duration = self.getDurationOf(tempTarget, withFinishDate: calculateFinishDate)
                        return self.getCopyOf(tempTarget, newDuration: duration)
                    }.forEach { item in
                        var mutableItem: TempTarget? = item

                        resultTempTargets.forEach { addedTempTarget in
                            guard mutableItem != nil else { return }

                            // insert tail of new temptarget
                            if self.getFinishDateOf(mutableItem!) > self.getFinishDateOf(addedTempTarget) {
                                let tail = self.getCopyOf(
                                    mutableItem!,
                                    newCreatedDate: self.getFinishDateOf(addedTempTarget),
                                    newDuration: self.getDurationBetween(
                                        self.getFinishDateOf(addedTempTarget),
                                        and: self.getFinishDateOf(mutableItem!)
                                    )
                                )
                                if tail.duration >= 1 {
                                    resultTempTargets.insert(tail, at: 0)
                                }
                            }

                            guard self.getFinishDateOf(mutableItem!) >= addedTempTarget.createdAt else { return }

                            mutableItem = self.getCopyOf(
                                item,
                                newCreatedDate: mutableItem!.createdAt,
                                newDuration: self.getDurationBetween(
                                    mutableItem!.createdAt,
                                    and: addedTempTarget.createdAt
                                )
                            )
                        }

                        if mutableItem != nil, mutableItem!.duration >= 1 {
                            resultTempTargets.insert(mutableItem!, at: 0)
                        }
                        resultTempTargets.sort { $0.createdAt > $1.createdAt }
                    }

                self.displayedTempTargets = resultTempTargets.reversed()
            }
        }

        private func getFinishDateOf(_ tempTarget: TempTarget, withDuration duration: Decimal? = nil) -> Date {
            tempTarget.createdAt.addingTimeInterval(Int(duration ?? tempTarget.duration).minutes.timeInterval)
        }

        private func getDurationOf(_ tempTarget: TempTarget, withFinishDate finishDate: Date) -> Decimal {
            Decimal(finishDate.timeIntervalSinceReferenceDate / 60 - tempTarget.createdAt.timeIntervalSinceReferenceDate / 60)
        }

        private func getDurationBetween(_ date1: Date, and date2: Date) -> Decimal {
            Decimal(date2.timeIntervalSinceReferenceDate / 60 - date1.timeIntervalSinceReferenceDate / 60)
        }

        private func getCopyOf(
            _ tempTarget: TempTarget,
            newCreatedDate createdAt: Date? = nil,
            newDuration duration: Decimal? = nil
        ) -> TempTarget {
            TempTarget(
                name: tempTarget.name,
                createdAt: createdAt ?? tempTarget.createdAt,
                targetTop: tempTarget.targetTop,
                targetBottom: tempTarget.targetBottom,
                duration: duration ?? tempTarget.duration,
                enteredBy: tempTarget.enteredBy,
                reason: tempTarget.reason
            )
        }

        func openCGM() {
            guard var url = nightscoutManager.cgmURL else { return }

            switch url.absoluteString {
            case "http://127.0.0.1:1979":
                url = URL(string: "spikeapp://")!
            case "http://127.0.0.1:17580":
                url = URL(string: "diabox://")!
            case CGMType.libreTransmitter.appURL?.absoluteString:
                showModal(for: .libreConfig)
            default: break
            }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

extension Home.StateModel:
    GlucoseObserver,
    SuggestionObserver,
    SettingsObserver,
    PumpHistoryObserver,
    PumpSettingsObserver,
    BasalProfileObserver,
    TempTargetsObserver,
    CarbsObserver,
    EnactedSuggestionObserver,
    PumpBatteryObserver,
    PumpReservoirObserver
{
    func glucoseDidUpdate(_: [BloodGlucose]) {
        setupGlucose()
    }

    func suggestionDidUpdate(_ suggestion: Suggestion) {
        self.suggestion = suggestion
        carbsRequired = suggestion.carbsReq
        setStatusTitle()
    }

    func settingsDidChange(_ settings: FreeAPSSettings) {
        allowManualTemp = !settings.closedLoop
        closedLoop = settingsManager.settings.closedLoop
        units = settingsManager.settings.units
        animatedBackground = settingsManager.settings.animatedBackground
        setupGlucose()
    }

    func pumpHistoryDidUpdate(_: [PumpHistoryEvent]) {
        setupBasals()
        setupBoluses()
        setupSuspensions()
    }

    func pumpSettingsDidChange(_: PumpSettings) {
        setupPumpSettings()
    }

    func basalProfileDidChange(_: [BasalProfileEntry]) {
        setupBasalProfile()
    }

    func tempTargetsDidUpdate(_: [TempTarget]) {
        setupTempTargets()
    }

    func carbsDidUpdate(_: [CarbsEntry]) {
        setupCarbs()
    }

    func enactedSuggestionDidUpdate(_ suggestion: Suggestion) {
        enactedSuggestion = suggestion
        setStatusTitle()
    }

    func pumpBatteryDidChange(_: Battery) {
        setupBattery()
    }

    func pumpReservoirDidChange(_: Decimal) {
        setupReservoir()
    }
}

extension Home.StateModel: CompletionDelegate {
    func completionNotifyingDidComplete(_: CompletionNotifying) {
        setupPump = false
    }
}
