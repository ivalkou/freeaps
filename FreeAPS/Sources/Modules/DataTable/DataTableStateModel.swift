import SwiftUI

extension DataTable {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var broadcaster: Broadcaster!
        @Published var mode: Mode = .treatments
        @Published var treatments: [Treatment] = []
        @Published var glucose: [Glucose] = []
        @Published var events: [EventEntry] = []
        var units: GlucoseUnits = .mmolL
        private var glucoseData: [BloodGlucose] = []

        override func subscribe() {
            units = settingsManager.settings.units
            setupTreatments()
            setupGlucose()
            setupEvents()
            broadcaster.register(SettingsObserver.self, observer: self)
            broadcaster.register(PumpHistoryObserver.self, observer: self)
            broadcaster.register(TempTargetsObserver.self, observer: self)
            broadcaster.register(CarbsObserver.self, observer: self)
            broadcaster.register(GlucoseObserver.self, observer: self)
            broadcaster.register(EventsObserver.self, observer: self)
        }

        private func setupTreatments() {
            DispatchQueue.global().async {
                let units = self.settingsManager.settings.units

                let carbs = self.provider.carbs().map {
                    Treatment(
                        id: UUID(uuidString: $0.id) ?? UUID(),
                        units: units,
                        type: .carbs,
                        date: $0.createdAt,
                        amount: $0.carbs,
                        note: $0.note
                    )
                }

                let boluses = self.provider.pumpHistory()
                    .filter { $0.type == .bolus }
                    .map {
                        Treatment(
                            units: units,
                            type: .bolus,
                            date: $0.timestamp,
                            amount: $0.amount,
                            insulinRecommendation: $0.insulinRecommendation
                        )
                    }

                let tempBasals = self.provider.pumpHistory()
                    .filter { $0.type == .tempBasal || $0.type == .tempBasalDuration }
                    .chunks(ofCount: 2)
                    .compactMap { chunk -> Treatment? in
                        let chunk = Array(chunk)
                        guard chunk.count == 2, chunk[0].type == .tempBasal,
                              chunk[1].type == .tempBasalDuration else { return nil }
                        return Treatment(
                            units: units,
                            type: .tempBasal,
                            date: chunk[0].timestamp,
                            amount: chunk[0].rate ?? 0,
                            secondAmount: nil,
                            duration: Decimal(chunk[1].durationMin ?? 0)
                        )
                    }

                let tempTargets = self.provider.tempTargets()
                    .map {
                        Treatment(
                            units: units,
                            type: .tempTarget,
                            date: $0.createdAt,
                            amount: $0.targetBottom ?? 0,
                            secondAmount: $0.targetTop,
                            duration: $0.duration
                        )
                    }

                let suspend = self.provider.pumpHistory()
                    .filter { $0.type == .pumpSuspend }
                    .map {
                        Treatment(units: units, type: .suspend, date: $0.timestamp)
                    }

                let resume = self.provider.pumpHistory()
                    .filter { $0.type == .pumpResume }
                    .map {
                        Treatment(units: units, type: .resume, date: $0.timestamp)
                    }

                DispatchQueue.main.async {
                    self.treatments = [carbs, boluses, tempBasals, tempTargets, suspend, resume]
                        .flatMap { $0 }
                        .sorted { $0.date > $1.date }
                }
            }
        }

        func setupGlucose() {
            let data = provider.glucose()
            DispatchQueue.main.async {
                self.glucoseData = data
                self.glucose = data.map(Glucose.init)
            }
        }

        func deleteCarbs(_ treatment: Treatment) {
            provider.deleteCarbs(treatment)
        }

        func deleteTempTarget(_ treatment: Treatment) {
            provider.deleteTempTarget(treatment)
        }

        func deleteGlucose(at index: Int) {
            let id = glucose[index].id
            provider.deleteGlucose(id: id)
        }

        func setupEvents() {
            DispatchQueue.main.async {
                self.events = self.provider.events()
            }
        }

        func deleteEvent(_ event: EventEntry) {
            provider.deleteEvent(id: event.id)
        }

        func nearestGlucose(to date: Date) -> BloodGlucose? {
            let maxInterval: TimeInterval = 15 * 60
            var closest: BloodGlucose?
            var closestInterval: TimeInterval = .greatestFiniteMagnitude
            for bg in glucoseData {
                guard bg.glucose != nil else { continue }
                let interval = abs(bg.dateString.timeIntervalSince(date))
                if interval < closestInterval {
                    closestInterval = interval
                    closest = bg
                }
            }
            guard closestInterval <= maxInterval else { return nil }
            return closest
        }
    }
}

extension DataTable.StateModel:
    SettingsObserver,
    PumpHistoryObserver,
    TempTargetsObserver,
    CarbsObserver,
    GlucoseObserver,
    EventsObserver
{
    func settingsDidChange(_: FreeAPSSettings) {
        setupTreatments()
    }

    func pumpHistoryDidUpdate(_: [PumpHistoryEvent]) {
        setupTreatments()
    }

    func tempTargetsDidUpdate(_: [TempTarget]) {
        setupTreatments()
    }

    func carbsDidUpdate(_: [CarbsEntry]) {
        setupTreatments()
    }

    func glucoseDidUpdate(_: [BloodGlucose]) {
        setupGlucose()
    }

    func eventsDidUpdate(_: [EventEntry]) {
        setupEvents()
    }
}
