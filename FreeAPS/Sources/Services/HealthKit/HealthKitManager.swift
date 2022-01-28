import Combine
import Foundation
import HealthKit
import Swinject

protocol HealthKitManager: GlucoseSource, CarbSource {
    /// Check all needed permissions
    /// Return false if one or more permissions are deny or not choosen
    var areAllowAllPermissions: Bool { get }
    /// Check availability to save data of BG type to Health store
    func checkAvailabilitySaveBG() -> Bool
    /// Check availability to save data of Carb type to Health store
    func checkAvailabilitySaveCarb() -> Bool
    /// Requests user to give permissions on using HealthKit
    func requestPermission(completion: ((Bool, Error?) -> Void)?)
    /// Save blood glucose to Health store (dublicate of bg will ignore)
    func saveIfNeeded(bloodGlucose: [BloodGlucose])
    /// Save carb to Health store (duplicates will be ignored)
    func saveIfNeeded(carbs: [CarbsEntry])
    /// Create observer for glucose data passing beetwen Health Store and FreeAPS
    func createGlucoseObserver()
    /// Create observer for carb data passing beetwen Health Store and FreeAPS
    func createCarbObserver()
    /// Enable background delivering objects from Apple Health to FreeAPS
    func enableBackgroundDelivery()
    /// Delete glucose with syncID
    func deleteGlucose(syncID: String)
    /// Delete carb at specified date
    func deleteCarb(syncID: String)
}

final class BaseHealthKitManager: HealthKitManager, Injectable {
    private enum Config {
        // unwraped HKObjects
        static var permissions: Set<HKSampleType> { Set(healthObjects.compactMap { $0 }) }

        // link to objects in HealthKit
        static let healthObjects = [
            HKObjectType.quantityType(forIdentifier: .bloodGlucose),
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)
        ]

        // Meta-data key of FreeASPX data in HealthStore
        static let freeAPSMetaKey = "fromFreeAPSX"
    }

    @Injected() private var healthKitStore: HKHealthStore!
    @Injected() private var settingsManager: SettingsManager!

    private let glucoseProcessQueue = DispatchQueue(label: "BaseHealthKitManager.glucoseProcessQueue")
    private let carbProcessQueue = DispatchQueue(label: "BaseHealthKitManager.carbProcessQueue")
    private var lifetime = Lifetime()

    // BG that will be return Publisher
    @SyncAccess @Persisted(key: "BaseHealthKitManager.newGlucose") private var newGlucose: [BloodGlucose] = []

    @SyncAccess @Persisted(key: "BaseHealthKitManager.newCarb") private var newCarb: [CarbsEntry] = []

    // last anchor for HKAnchoredQuery
    private var lastBloodGlucoseQueryAnchor: HKQueryAnchor? {
        set {
            persistedAnchor = try? NSKeyedArchiver.archivedData(withRootObject: newValue as Any, requiringSecureCoding: false)
        }
        get {
            guard let data = persistedAnchor else { return nil }
            return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? HKQueryAnchor
        }
    }

    private var lastCarbQueryAnchor: HKQueryAnchor? {
        set {
            persistedAnchor = try? NSKeyedArchiver.archivedData(withRootObject: newValue as Any, requiringSecureCoding: false)
        }
        get {
            guard let data = persistedAnchor else { return nil }
            return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? HKQueryAnchor
        }
    }

    @Persisted(key: "HealthKitManagerAnchor") private var persistedAnchor: Data? = nil

    var isAvailableOnCurrentDevice: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var areAllowAllPermissions: Bool {
        Set(Config.permissions.map { healthKitStore.authorizationStatus(for: $0) })
            .intersection([.sharingDenied, .notDetermined])
            .isEmpty
    }

    // NSPredicate, which use during load increment values from Health store
    private var loadValuePredicate: NSPredicate {
        // loading only daily values
        let predicateByStartDate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-1.days.timeInterval),
            end: nil,
            options: .strictStartDate
        )

        // loading only not FreeAPS values
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
              !Config.healthObjects.isEmpty else { return }
        createGlucoseObserver()
        createCarbObserver()
        enableBackgroundDelivery()
        debug(.service, "HealthKitManager did create")
    }

    func checkAvailabilitySave(objectTypeToHealthStore: HKObjectType) -> Bool {
        healthKitStore.authorizationStatus(for: objectTypeToHealthStore) == .sharingAuthorized
    }

    func checkAvailabilitySaveBG() -> Bool {
        Config.healthObjects[0].map { checkAvailabilitySave(objectTypeToHealthStore: $0) } ?? false
    }

    func checkAvailabilitySaveCarb() -> Bool {
        Config.healthObjects[1].map { checkAvailabilitySave(objectTypeToHealthStore: $0) } ?? false
    }

    func requestPermission(completion: ((Bool, Error?) -> Void)? = nil) {
        guard isAvailableOnCurrentDevice else {
            completion?(false, HKError.notAvailableOnCurrentDevice)
            return
        }
        guard Config.permissions.isNotEmpty else {
            completion?(false, HKError.dataNotAvailable)
            return
        }

        healthKitStore.requestAuthorization(toShare: Config.permissions, read: Config.permissions) { status, error in
            completion?(status, error)
        }
    }

    func saveIfNeeded(bloodGlucose: [BloodGlucose]) {
        guard settingsManager.settings.useAppleHealth,
              let sampleType = Config.healthObjects[0],
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
            .receive(on: glucoseProcessQueue)
            .sink(receiveValue: save)
            .store(in: &lifetime)
    }

    func saveIfNeeded(carbs: [CarbsEntry]) {
        guard settingsManager.settings.useAppleHealth,
              let sampleType = Config.healthObjects[1],
              checkAvailabilitySave(objectTypeToHealthStore: sampleType),
              carbs.isNotEmpty
        else { return }

        func save(samples: [HKSample]) {
            let sampleIDs = samples.compactMap(\.syncIdentifier)
            let samplesToSave = carbs
                .filter { !sampleIDs.contains($0.id) }
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
            .receive(on: carbProcessQueue)
            .sink(receiveValue: save)
            .store(in: &lifetime)
    }

    func createGlucoseObserver() {
        guard settingsManager.settings.useAppleHealth else { return }

        guard let bgType = Config.healthObjects[0] else {
            warning(.service, "Can not create HealthKit Observer, because unable to get the Blood Glucose type")
            return
        }

        let glucoseQuery = HKObserverQuery(sampleType: bgType, predicate: nil) { [weak self] _, _, observerError in
            guard let self = self else { return }
            debug(.service, "Execute HelathKit observer query for loading increment samples")
            guard observerError == nil else {
                warning(.service, "Error during execution of HelathKit Observer's query", error: observerError!)
                return
            }

            if let incrementQuery = self.getBloodGlucoseHKQuery(predicate: self.loadValuePredicate) {
                debug(.service, "Create increment query")
                self.healthKitStore.execute(incrementQuery)
            }
        }

        healthKitStore.execute(glucoseQuery)
        debug(.service, "Create Observer for Blood Glucose")
    }

    func createCarbObserver() {
        guard settingsManager.settings.useAppleHealth else { return }

        guard let carbType = Config.healthObjects[1] else {
            warning(.service, "Can not create HealthKit Observer, because unable to get the Carb type")
            return
        }

        let carbQuery = HKObserverQuery(sampleType: carbType, predicate: nil) { [weak self] _, _, observerError in
            guard let self = self else { return }
            debug(.service, "Execute HelathKit observer query for loading increment samples")
            guard observerError == nil else {
                warning(.service, "Error during execution of HelathKit Observer's query", error: observerError!)
                return
            }

            if let incrementQuery = self.getCarbHKQuery(predicate: self.loadValuePredicate) {
                debug(.service, "Create carb increment query")
                self.healthKitStore.execute(incrementQuery)
            }
        }

        healthKitStore.execute(carbQuery)
        debug(.service, "Create Observer for Carbohydrate")
    }

    func enableBackgroundDelivery() {
        guard settingsManager.settings.useAppleHealth else {
            healthKitStore.disableAllBackgroundDelivery { _, _ in }
            return }

        guard let bgType = Config.healthObjects[0] else {
            warning(
                .service,
                "Can not create background delivery, because unable to get the Blood Glucose type"
            )
            return
        }

        guard let carbType = Config.healthObjects[1] else {
            warning(
                .service,
                "Can not create background delivery, because unable to get the Carb type"
            )
            return
        }

        healthKitStore.enableBackgroundDelivery(for: bgType, frequency: .immediate) { status, error in
            guard error == nil else {
                warning(.service, "Can not enable bg background delivery", error: error)
                return
            }
            debug(.service, "Background delivery bg status is \(status)")
        }

        healthKitStore.enableBackgroundDelivery(for: carbType, frequency: .immediate) { status, error in
            guard error == nil else {
                warning(.service, "Can not enable carb background delivery", error: error)
                return
            }
            debug(.service, "Background delivery carb status is \(status)")
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
        guard let sampleType = Config.healthObjects[0] else { return nil }

        let query = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: predicate,
            anchor: lastBloodGlucoseQueryAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, addedObjects, _, anchor, _ in
            guard let self = self else { return }
            self.glucoseProcessQueue.async {
                debug(.service, "AnchoredQuery for glucose did execute")

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

    private func getCarbHKQuery(predicate: NSPredicate) -> HKQuery? {
        guard let sampleType = Config.healthObjects[1] else { return nil }

        let query = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: predicate,
            anchor: lastCarbQueryAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, addedObjects, _, anchor, _ in
            guard let self = self else { return }
            self.carbProcessQueue.async {
                debug(.service, "AnchoredQuery for carbs did execute")

                self.lastCarbQueryAnchor = anchor

                // Added objects
                debug(.service, "getCarbHKQuery: \(String(describing: addedObjects))")
                if let carbSamples = addedObjects as? [HKQuantitySample],
                   carbSamples.isNotEmpty
                {
                    self.prepareCarbSamplesToPublisherFetch(carbSamples)
                }
            }
        }
        return query
    }

    private func prepareBGSamplesToPublisherFetch(_ samples: [HKQuantitySample]) {
        dispatchPrecondition(condition: .onQueue(glucoseProcessQueue))
        debug(.service, "Start preparing samples: \(String(describing: samples))")

        newGlucose += samples
            .compactMap { sample -> HealthKitSample? in
                let fromFAX = sample.metadata?[Config.freeAPSMetaKey] as? Bool ?? false
                guard !fromFAX else { return nil }
                return HealthKitSample(
                    healthKitId: sample.uuid.uuidString,
                    date: sample.startDate,
                    glucose: Int(round(sample.quantity.doubleValue(for: .milligramsPerDeciliter))),
                    carb: nil
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

    private func prepareCarbSamplesToPublisherFetch(_ samples: [HKQuantitySample]) {
        dispatchPrecondition(condition: .onQueue(carbProcessQueue))
        debug(.service, "Start preparing samples: \(String(describing: samples))")

        newCarb += samples
            .compactMap { sample -> HealthKitSample? in
                let fromFAX = sample.metadata?[Config.freeAPSMetaKey] as? Bool ?? false
                guard !fromFAX else { return nil }
                return HealthKitSample(
                    healthKitId: sample.uuid.uuidString,
                    date: sample.startDate,
                    glucose: nil,
                    carb: sample.quantity.doubleValue(for: .gram()).decimal
                )
            }
            .map { sample in
                CarbsEntry(
                    id: sample.healthKitId,
                    createdAt: sample.date,
                    carbs: sample.carb as? Decimal ?? 0.0,
                    enteredBy: CarbsEntry.healthKit
                )
            }
            .filter { $0.createdAt >= Date().addingTimeInterval(-1.days.timeInterval) }

        newCarb = newCarb.removeDublicates()

        debug(
            .service,
            "Current Carb.Type objects will be send from Publisher during fetch: \(String(describing: newCarb))"
        )
    }

    func fetch() -> AnyPublisher<[BloodGlucose], Never> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }

            self.glucoseProcessQueue.async {
                debug(.service, "Start fetching HealthKitManager Glucose")
                guard self.settingsManager.settings.useAppleHealth else {
                    debug(.service, "HealthKitManager cant return any glucose data, because useAppleHealth option is disable")
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

    func fetchCarbs() -> AnyPublisher<[CarbsEntry], Never> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }

            self.carbProcessQueue.async {
                debug(.service, "Start fetching HealthKitManager Carbs")
                guard self.settingsManager.settings.useAppleHealth else {
                    debug(.service, "HealthKitManager cant return any carb data, because useAppleHealth option is disable")
                    promise(.success([]))
                    return
                }

                debug(.service, "Old state of newCarb is \(self.newCarb)")

                // Remove old carbs
                self.newCarb = self.newCarb
                    .filter { $0.createdAt >= Date().addingTimeInterval(-1.days.timeInterval) }
                // Get actual carbs (beetwen Date() - 1 day and Date())
                let actualCarb = self.newCarb
                    .filter { $0.createdAt <= Date() }
                // Update newCarb
                self.newCarb = self.newCarb
                    .filter { !actualCarb.contains($0) }

                debug(.service, "Actual carb is \(actualCarb)")

                debug(.service, "Current state of newCarb is \(self.newCarb)")

                promise(.success(actualCarb))
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteGlucose(syncID: String) {
        guard settingsManager.settings.useAppleHealth,
              let sampleType = Config.healthObjects[0],
              checkAvailabilitySave(objectTypeToHealthStore: sampleType)
        else { return }

        glucoseProcessQueue.async {
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

    func deleteCarb(syncID: String) {
        guard settingsManager.settings.useAppleHealth,
              let sampleType = Config.healthObjects[1],
              checkAvailabilitySave(objectTypeToHealthStore: sampleType)
        else { return }

        carbProcessQueue.async {
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
