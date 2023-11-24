import Combine
import Foundation
import HealthKit
import LoopKit
import Swinject

protocol HealthKitManager: GlucoseSource, CarbsSource {
    /// Requests user to give permissions to using HealthKit
    func requestPermission(completion: ((Bool, Error?) -> Void)?)
    /// Save blood glucose to Health store (dublicate of bg will ignore)
    func saveIfNeeded(bloodGlucose: [BloodGlucose])
    /// Save carbs to Health store (dublicate of bg will ignore)
    func saveIfNeeded(carbs: [CarbsEntry])
    /// Save pumpHistoryEvents (basal and bolus event)
    func saveIfNeeded(pumpEvents: [PumpHistoryEvent])
    /// Configure HealthKit manager
    func configureManager()
    /// Delete glucose with syncID
    func deleteCarbs(syncID: String)
    /// Delete glucose with syncID
    func deleteGlucose(syncID: String)
}

final class BaseHealthKitManager: HealthKitManager, Injectable {
    private enum Config {
        // permissions for write and read
        static var readPermissions: Set<HKSampleType> { Set([healthBGObject, healthCarbObject].compactMap { $0 }) }
        static var writePermissions: Set<HKSampleType> {
            Set([healthBGObject, healthCarbObject, healthInsulinObject].compactMap { $0 }) }

        // link to object in HealthKit
        static let healthBGObject = HKObjectType.quantityType(forIdentifier: .bloodGlucose)
        static let healthCarbObject = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)
        static let healthInsulinObject = HKObjectType.quantityType(forIdentifier: .insulinDelivery)

        // Meta-data key of FreeASPX data in HealthStore
        static let freeAPSMetaKey = "fromFreeAPSX"
    }

    @Injected() private var glucoseStorage: GlucoseStorage!
    @Injected() private var healthKitStore: HKHealthStore!
    @Injected() private var settingsManager: SettingsManager!
    @Injected() private var broadcaster: Broadcaster!

    private let processQueue = DispatchQueue(label: "BaseHealthKitManager.processQueue")
    private var lifetime = Lifetime()

    // BG that will be return Publisher (GlucoseSource protocol)
    @SyncAccess @Persisted(key: "BaseHealthKitManager.newGlucose") private var newGlucose: [BloodGlucose] = []
    // Carbs that will be return Publisher (CarbsSource protocol)
    @SyncAccess @Persisted(key: "BaseHealthKitManager.newCarbs") private var newCarbs: [CarbsEntry] = []

    // last anchor for HKAnchoredQuery
    // BG
    private var lastBloodGlucoseQueryAnchor: HKQueryAnchor? {
        set {
            persistedBGAnchor = try? NSKeyedArchiver.archivedData(withRootObject: newValue as Any, requiringSecureCoding: false)
        }
        get {
            guard let data = persistedBGAnchor else { return nil }
            return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? HKQueryAnchor
        }
    }

    @Persisted(key: "HealthKitManagerAnchor") private var persistedBGAnchor: Data? = nil
    // Carbs
    private var lastCarbsQueryAnchor: HKQueryAnchor? {
        set {
            persistedCarbsAnchor = try? NSKeyedArchiver.archivedData(
                withRootObject: newValue as Any,
                requiringSecureCoding: false
            )
        }
        get {
            guard let data = persistedCarbsAnchor else { return nil }
            return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? HKQueryAnchor
        }
    }

    @Persisted(key: "HealthKitManagerAnchor_Carbs") private var persistedCarbsAnchor: Data? = nil

    var isAvailableOnCurrentDevice: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // NSPredicate, which use during load increment BG from Health store
    private var loadHealthDataPredicate: NSPredicate {
        // loading only daily bg
        let predicateByStartDate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-1.days.timeInterval),
            end: nil,
            options: .strictStartDate
        )

        // loading only not FreeAPS bg
        // this predicate dont influence on Deleted Objects, only on added
        let predicateByMeta = HKQuery.predicateForObjects(
            withMetadataKey: Config.freeAPSMetaKey,
            operatorType: .notEqualTo,
            value: 1
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [predicateByStartDate, predicateByMeta])
    }

    init(resolver: Resolver) {
        injectServices(resolver)
        guard isAvailableOnCurrentDevice,
              Config.healthBGObject != nil else { return }
        configureManager()
        subscribe()
        debug(.service, "HealthKitManager did create")
    }

    func configureManager() {
        createObserver()
        enableBackgroundDelivery()
        debug(.service, "HealthKitManager did configured")
    }

    private func subscribe() {
        broadcaster.register(CarbsObserver.self, observer: self)
    }

    func checkAvailabilitySave(objectTypeToHealthStore: HKObjectType) -> Bool {
        healthKitStore.authorizationStatus(for: objectTypeToHealthStore) == .sharingAuthorized
    }

    func requestPermission(completion: ((Bool, Error?) -> Void)? = nil) {
        guard isAvailableOnCurrentDevice else {
            completion?(false, HKError.notAvailableOnCurrentDevice)
            return
        }
        guard Config.readPermissions.isNotEmpty, Config.writePermissions.isNotEmpty else {
            completion?(false, HKError.dataNotAvailable)
            return
        }

        healthKitStore.requestAuthorization(toShare: Config.writePermissions, read: Config.readPermissions) { status, error in
            completion?(status, error)
        }
    }

    func saveIfNeeded(carbs: [CarbsEntry]) {
        guard settingsManager.settings.useAppleHealth,
              let sampleType = Config.healthCarbObject,
              checkAvailabilitySave(objectTypeToHealthStore: sampleType),
              carbs.isNotEmpty
        else { return }

        func save(samples: [HKSample]) {
            let sampleIDs = samples.compactMap(\.syncIdentifier)
            let samplesToSave = carbs
                .filter { !sampleIDs.contains($0.id) }
                .filter { $0.enteredBy != CarbsEntry.applehealth }
                .map {
                    HKQuantitySample(
                        type: sampleType,
                        quantity: HKQuantity(unit: .gram(), doubleValue: Double($0.carbs)),
                        start: $0.createdAt,
                        end: $0.createdAt,
                        metadata: [
                            HKMetadataKeyExternalUUID: $0.id,
                            HKMetadataKeySyncIdentifier: $0.id,
                            HKMetadataKeySyncVersion: 1,
                            Config.freeAPSMetaKey: true
                        ]
                    )
                }

            healthKitStore.save(samplesToSave) { _, _ in }
        }

        loadSamplesFromHealth(sampleType: sampleType, withIDs: carbs.map(\.id))
            .receive(on: processQueue)
            .sink(receiveValue: save)
            .store(in: &lifetime)
    }

    func saveIfNeeded(bloodGlucose: [BloodGlucose]) {
        guard settingsManager.settings.useAppleHealth,
              let sampleType = Config.healthBGObject,
              checkAvailabilitySave(objectTypeToHealthStore: sampleType),
              bloodGlucose.isNotEmpty
        else { return }

        func save(samples: [HKSample]) {
            let sampleIDs = samples.compactMap(\.syncIdentifier)
            let samplesToSave = bloodGlucose
                .filter { !sampleIDs.contains($0.id) }
                .map {
                    HKQuantitySample(
                        type: sampleType,
                        quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: Double($0.glucose!)),
                        start: $0.dateString,
                        end: $0.dateString,
                        metadata: [
                            HKMetadataKeyExternalUUID: $0.id,
                            HKMetadataKeySyncIdentifier: $0.id,
                            HKMetadataKeySyncVersion: 1,
                            Config.freeAPSMetaKey: true
                        ]
                    )
                }

            healthKitStore.save(samplesToSave) { _, _ in }
        }

        loadSamplesFromHealth(sampleType: sampleType, withIDs: bloodGlucose.map(\.id))
            .receive(on: processQueue)
            .sink(receiveValue: save)
            .store(in: &lifetime)
    }

    func saveIfNeeded(pumpEvents events: [PumpHistoryEvent]) {
        guard settingsManager.settings.useAppleHealth,
              let sampleType = Config.healthInsulinObject,
              checkAvailabilitySave(objectTypeToHealthStore: sampleType),
              events.isNotEmpty
        else { return }

        loadSamplesFromHealth(sampleType: sampleType, withIDs: events.map(\.id))
            .receive(on: processQueue)
            .compactMap { samples -> ([InsulinBolus], [InsulinBasal]) in
                let sampleIDs = samples.compactMap(\.syncIdentifier)
                let bolus = events
                    .filter { $0.type == .bolus && !sampleIDs.contains($0.id) }
                    .compactMap { event -> InsulinBolus? in
                        guard let amount = event.amount else { return nil }
                        return InsulinBolus(id: event.id, amount: amount, date: event.timestamp)
                    }
                let basalEvents = events
                    .filter { $0.type == .tempBasal && !sampleIDs.contains($0.id) }
                let basal = basalEvents.enumerated()
                    .compactMap { item -> InsulinBasal? in
                        let nextElementEventIndex = item.offset + 1
                        guard basalEvents.count > nextElementEventIndex else { return nil }
                        let nextBasalEvent = basalEvents[nextElementEventIndex]
                        let secondsOfCurrentBasal = nextBasalEvent.timestamp.timeIntervalSince(item.element.timestamp)
                        let amount = Decimal(secondsOfCurrentBasal / 3600) * (item.element.rate ?? 0)
                        let id = String(item.element.id.dropFirst())
                        guard amount > 0,
                              id != ""
                        else { return nil }
                        return InsulinBasal(
                            id: id,
                            amount: amount,
                            startDelivery: item.element.timestamp,
                            endDelivery: nextBasalEvent.timestamp
                        )
                    }
                return (bolus, basal)
            }
            .sink(receiveValue: { bolus, basal in
                // save bolus
                let bolusSamples = bolus
                    .map {
                        HKQuantitySample(
                            type: sampleType,
                            quantity: HKQuantity(unit: .internationalUnit(), doubleValue: Double($0.amount)),
                            start: $0.date,
                            end: $0.date,
                            metadata: [
                                HKMetadataKeyInsulinDeliveryReason: NSNumber(2),
                                HKMetadataKeyExternalUUID: $0.id,
                                HKMetadataKeySyncIdentifier: $0.id,
                                HKMetadataKeySyncVersion: 1,
                                Config.freeAPSMetaKey: true
                            ]
                        )
                    }

                let basalSamples = basal
                    .map {
                        HKQuantitySample(
                            type: sampleType,
                            quantity: HKQuantity(unit: .internationalUnit(), doubleValue: Double($0.amount)),
                            start: $0.startDelivery,
                            end: $0.endDelivery,
                            metadata: [
                                HKMetadataKeyInsulinDeliveryReason: NSNumber(1),
                                HKMetadataKeyExternalUUID: $0.id,
                                HKMetadataKeySyncIdentifier: $0.id,
                                HKMetadataKeySyncVersion: 1,
                                Config.freeAPSMetaKey: true
                            ]
                        )
                    }

                self.healthKitStore.save(bolusSamples + basalSamples) { _, _ in }
            })
            .store(in: &lifetime)
    }

    // MARK: - Observers & Background data delivery

    private func createObserver() {
        guard settingsManager.settings.useAppleHealth else { return }

        createBGObserver()
        createCarbsObserver()
    }

    private func createBGObserver() {
        guard let type = Config.healthBGObject else {
            warning(.service, "Can not create HealthKit Observer, because unable to get the Blood Glucose type")
            return
        }
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, _, observerError in
            guard let self = self else { return }
            debug(.service, "Execute HealthKit observer query for loading increment samples")
            guard observerError == nil else {
                warning(.service, "Error during execution of HealthKit Observer's query", error: observerError!)
                return
            }

            if let incrementQuery = self.getBloodGlucoseHKQuery(predicate: self.loadHealthDataPredicate) {
                debug(.service, "Create increment query for loading bg")
                self.healthKitStore.execute(incrementQuery)
            }
        }
        healthKitStore.execute(query)
        debug(.service, "Create Observer for Blood Glucose")
    }

    private func createCarbsObserver() {
        guard let type = Config.healthCarbObject else {
            warning(.service, "Can not create HealthKit Observer, because unable to get the Carbs type")
            return
        }
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, _, observerError in
            guard let self = self else { return }
            debug(.service, "Execute HealthKit observer query for loading increment samples")
            guard observerError == nil else {
                warning(.service, "Error during execution of HealthKit Observer's query", error: observerError!)
                return
            }

            if let incrementQuery = self.getCarbsHKQuery(predicate: self.loadHealthDataPredicate) {
                debug(.service, "Create increment query for loading carbs")
                self.healthKitStore.execute(incrementQuery)
            }
        }
        healthKitStore.execute(query)
        debug(.service, "Create Observer for Carbs")
    }

    private func enableBackgroundDelivery() {
        guard settingsManager.settings.useAppleHealth else {
            healthKitStore.disableAllBackgroundDelivery { _, _ in }
            return }

        guard let bgType = Config.healthBGObject else {
            warning(
                .service,
                "Can not create background delivery, because unable to get the Blood Glucose type"
            )
            return
        }

        healthKitStore.enableBackgroundDelivery(for: bgType, frequency: .immediate) { status, error in
            guard error == nil else {
                warning(.service, "Can not enable background delivery for bg", error: error)
                return
            }
            debug(.service, "Background bg delivery status is \(status)")
        }

        guard let carbsType = Config.healthCarbObject else {
            warning(
                .service,
                "Can not create background delivery, because unable to get the Carbs type"
            )
            return
        }

        healthKitStore.enableBackgroundDelivery(for: carbsType, frequency: .immediate) { status, error in
            guard error == nil else {
                warning(.service, "Can not enable background delivery for carbs", error: error)
                return
            }
            debug(.service, "Background carbs delivery status is \(status)")
        }
    }

    /// Try to load samples from Health store with id and do some work
    private func loadSamplesFromHealth(
        sampleType: HKQuantityType,
        withIDs ids: [String]
    ) -> Future<[HKSample], Never> {
        Future { promise in
            let predicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeySyncIdentifier,
                allowedValues: ids
            )

            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: 1000,
                sortDescriptors: nil
            ) { _, results, _ in
                promise(.success((results as? [HKQuantitySample]) ?? []))
            }
            self.healthKitStore.execute(query)
        }
    }

    private func getBloodGlucoseHKQuery(predicate: NSPredicate) -> HKQuery? {
        guard let sampleType = Config.healthBGObject else { return nil }

        let query = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: predicate,
            anchor: lastBloodGlucoseQueryAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, addedObjects, _, anchor, _ in
            guard let self = self else { return }
            self.processQueue.async {
                debug(.service, "BG AnchoredQuery did execute")

                self.lastBloodGlucoseQueryAnchor = anchor

                // Added objects
                if let bgSamples = addedObjects as? [HKQuantitySample],
                   bgSamples.isNotEmpty
                {
                    self.prepareBGSamplesToPublisherFetch(bgSamples)
                }
            }
        }
        return query
    }

    private func getCarbsHKQuery(predicate: NSPredicate) -> HKQuery? {
        guard let sampleType = Config.healthCarbObject else { return nil }

        let query = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: predicate,
            anchor: lastCarbsQueryAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, addedObjects, _, anchor, _ in
            guard let self = self else { return }
            self.processQueue.async {
                debug(.service, "Carbs AnchoredQuery did execute")

                self.lastCarbsQueryAnchor = anchor

                // Added objects
                if let samples = addedObjects as? [HKQuantitySample],
                   samples.isNotEmpty
                {
                    self.prepareCarbsSamplesToPublisherFetch(samples)
                }
            }
        }
        return query
    }

    private func prepareCarbsSamplesToPublisherFetch(_ samples: [HKQuantitySample]) {
        dispatchPrecondition(condition: .onQueue(processQueue))
        debug(.service, "Start preparing carbs samples: \(String(describing: samples))")

        newCarbs += samples
            .compactMap { sample -> HealthKitCarbsSample? in
                let fromFAX = sample.metadata?[Config.freeAPSMetaKey] as? Bool ?? false
                guard !fromFAX else { return nil }
                return HealthKitCarbsSample(
                    healthKitId: sample.uuid.uuidString,
                    date: sample.startDate,
                    carbs: Decimal(round(sample.quantity.doubleValue(for: .gram())))
                )
            }
            .map { sample in
                CarbsEntry(
                    id: sample.healthKitId,
                    createdAt: sample.date,
                    carbs: sample.carbs,
                    enteredBy: "applehealth"
                )
            }
            .filter { $0.createdAt >= Date().addingTimeInterval(-1.days.timeInterval) }

        newCarbs = newCarbs.removeDublicates()

        debug(
            .service,
            "Current Carbs.Type objects will be send from Publisher during fetch: \(String(describing: newCarbs))"
        )
    }

    private func prepareBGSamplesToPublisherFetch(_ samples: [HKQuantitySample]) {
        dispatchPrecondition(condition: .onQueue(processQueue))
        debug(.service, "Start preparing bg samples: \(String(describing: samples))")

        newGlucose += samples
            .compactMap { sample -> HealthKitBGSample? in
                let fromFAX = sample.metadata?[Config.freeAPSMetaKey] as? Bool ?? false
                guard !fromFAX else { return nil }
                return HealthKitBGSample(
                    healthKitId: sample.uuid.uuidString,
                    date: sample.startDate,
                    glucose: Int(round(sample.quantity.doubleValue(for: .milligramsPerDeciliter)))
                )
            }
            .map { sample in
                BloodGlucose(
                    _id: sample.healthKitId,
                    sgv: sample.glucose,
                    direction: nil,
                    date: Decimal(Int(sample.date.timeIntervalSince1970) * 1000),
                    dateString: sample.date,
                    unfiltered: nil,
                    filtered: nil,
                    noise: nil,
                    glucose: sample.glucose,
                    type: "sgv"
                )
            }
            .filter { $0.dateString >= Date().addingTimeInterval(-1.days.timeInterval) }

        newGlucose = newGlucose.removeDublicates()

        debug(
            .service,
            "Current BloodGlucose.Type objects will be send from Publisher during fetch: \(String(describing: newGlucose))"
        )
    }

    // MARK: - Carbs source

    func fetchCarbs() -> AnyPublisher<[CarbsEntry], Never> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }

            self.processQueue.async {
                debug(.service, "Start fetching carbs from HealthKitManager")
                guard self.settingsManager.settings.useAppleHealth else {
                    debug(.service, "HealthKitManager cant return any data, because useAppleHealth option is disable")
                    promise(.success([]))
                    return
                }

                // Remove old Carbs
                self.newCarbs = self.newCarbs
                    .filter { $0.createdAt >= Date().addingTimeInterval(-1.days.timeInterval) }
                // Get actual Carbs (beetwen Date() - 1 day and Date())
                let actualCarbs = self.newCarbs
                    .filter { $0.createdAt <= Date() }
                // Update newCarbs
                self.newCarbs = self.newCarbs
                    .filter { !actualCarbs.contains($0) }

                debug(.service, "Actual carbs is \(actualCarbs)")

                debug(.service, "Current state of newCarbs is \(self.newCarbs)")

                promise(.success(actualCarbs))
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteCarbs(syncID: String) {
        guard settingsManager.settings.useAppleHealth,
              let sampleType = Config.healthCarbObject,
              checkAvailabilitySave(objectTypeToHealthStore: sampleType)
        else { return }

        processQueue.async {
            let predicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeySyncIdentifier,
                operatorType: .equalTo,
                value: syncID
            )

            self.healthKitStore.deleteObjects(of: sampleType, predicate: predicate) { _, _, error in
                guard let error = error else { return }
                warning(.service, "Cannot delete sample with syncID: \(syncID)", error: error)
            }
        }
    }

    // MARK: - Glucose source

    func fetch() -> AnyPublisher<[BloodGlucose], Never> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }

            self.processQueue.async {
                debug(.service, "Start fetching bloodGlucose from HealthKitManager")
                guard self.settingsManager.settings.useAppleHealth else {
                    debug(.service, "HealthKitManager cant return any data, because useAppleHealth option is disable")
                    promise(.success([]))
                    return
                }

                // Remove old BGs
                self.newGlucose = self.newGlucose
                    .filter { $0.dateString >= Date().addingTimeInterval(-1.days.timeInterval) }
                // Get actual BGs (beetwen Date() - 1 day and Date())
                let actualGlucose = self.newGlucose
                    .filter { $0.dateString <= Date() }
                // Update newGlucose
                self.newGlucose = self.newGlucose
                    .filter { !actualGlucose.contains($0) }

                debug(.service, "Actual glucose is \(actualGlucose)")

                debug(.service, "Current state of newGlucose is \(self.newGlucose)")

                promise(.success(actualGlucose))
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteGlucose(syncID: String) {
        guard settingsManager.settings.useAppleHealth,
              let sampleType = Config.healthBGObject,
              checkAvailabilitySave(objectTypeToHealthStore: sampleType)
        else { return }

        processQueue.async {
            let predicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeySyncIdentifier,
                operatorType: .equalTo,
                value: syncID
            )

            self.healthKitStore.deleteObjects(of: sampleType, predicate: predicate) { _, _, error in
                guard let error = error else { return }
                warning(.service, "Cannot delete sample with syncID: \(syncID)", error: error)
            }
        }
    }
}

extension BaseHealthKitManager: CarbsObserver {
    func carbsDidUpdate(_ carbs: [CarbsEntry]) {
        saveIfNeeded(carbs: carbs)
    }
}

// MARK: Subtypes

enum HealthKitPermissionRequestStatus {
    case needRequest
    case didRequest
}

enum HKError: Error {
    // HealthKit work only iPhone (not on iPad)
    case notAvailableOnCurrentDevice
    // Some data can be not available on current iOS-device
    case dataNotAvailable
}

private struct InsulinBolus {
    var id: String
    var amount: Decimal
    var date: Date
}

private struct InsulinBasal {
    var id: String
    var amount: Decimal
    var startDelivery: Date
    var endDelivery: Date
}
