import Combine
import Foundation
import HealthKit
import Swinject

protocol HealthKitManager: GlucoseSource {
    /// Check availability HealthKit on current device and user's permissions
    var isAvailableOnCurrentDevice: Bool { get }
    /// Check all needed permissions
    /// Return false if one or more permissions are deny or not choosen
    var areAllowAllPermissions: Bool { get }
    /// Check availability to save data of concrete type to Health store
    func checkAvailabilitySave(objectTypeToHealthStore: HKObjectType) -> Bool
    /// Requests user to give permissions on using HealthKit
    func requestPermission(completion: ((Bool, Error?) -> Void)?)
    /// Save blood glucose to Health store (dublicate of bg will ignore)
    func saveIfNeeded(bloodGlucoses: [BloodGlucose])
    /// Create observer for data passing beetwen Health Store and FreeAPS
    func createObserver()
    /// Enable background delivering objects from Apple Health to FreeAPS
    func enableBackgroundDelivery()
}

final class BaseHealthKitManager: HealthKitManager, Injectable {
    @Injected() private var fileStorage: FileStorage!
    @Injected() private var glucoseStorage: GlucoseStorage!
    @Injected() private var healthKitStore: HKHealthStore!
    @Injected() private var settingsManager: SettingsManager!

    private enum Config {
        // unwraped HKObjects
        static var permissions: Set<HKSampleType> {
            var result: Set<HKSampleType> = []
            for permission in optionalPermissions {
                result.insert(permission!)
            }
            return result
        }

        static let optionalPermissions = Set([Config.healthBGObject])
        // link to object in HealthKit
        static let healthBGObject = HKObjectType.quantityType(forIdentifier: .bloodGlucose)

        static let frequencyBackgroundDeliveryBloodGlucoseFromHealth = HKUpdateFrequency(rawValue: 10)!
        // Meta-data key of FreeASPX data in HealthStore
        static let freeAPSMetaKey = "fromFreeAPSX"
    }

    private var newGlucose: [BloodGlucose] = []

    var isAvailableOnCurrentDevice: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var areAllowAllPermissions: Bool {
        var result = true
        Config.permissions.forEach { permission in
            if [HKAuthorizationStatus.sharingDenied, HKAuthorizationStatus.notDetermined]
                .contains(healthKitStore.authorizationStatus(for: permission))
            {
                result = false
            }
        }
        return result
    }

    init(resolver: Resolver) {
        injectServices(resolver)
        guard isAvailableOnCurrentDevice,
              Config.healthBGObject != nil else { return }
        createObserver()
        enableBackgroundDelivery()
        debug(.service, "HealthKitManager did create")
    }

    func checkAvailabilitySave(objectTypeToHealthStore: HKObjectType) -> Bool {
        let status = healthKitStore.authorizationStatus(for: objectTypeToHealthStore)
        switch status {
        case .sharingAuthorized:
            return true
        default:
            return false
        }
    }

    func requestPermission(completion: ((Bool, Error?) -> Void)? = nil) {
        guard isAvailableOnCurrentDevice else {
            completion?(false, HKError.notAvailableOnCurrentDevice)
            return
        }
        for permission in Config.optionalPermissions {
            guard permission != nil else {
                completion?(false, HKError.dataNotAvailable)
                return
            }
        }

        healthKitStore.requestAuthorization(toShare: Config.permissions, read: Config.permissions) { status, error in
            completion?(status, error)
        }
    }

    func saveIfNeeded(bloodGlucoses: [BloodGlucose]) {
        guard settingsManager.settings.useAppleHealth,
              let sampleType = Config.healthBGObject,
              checkAvailabilitySave(objectTypeToHealthStore: sampleType),
              bloodGlucoses.isNotEmpty
        else { return }

        for bgItem in bloodGlucoses {
            let bgQuantity = HKQuantity(
                unit: .milligramsPerDeciliter,
                doubleValue: Double(bgItem.glucose!)
            )

            let bgObjectSample = HKQuantitySample(
                type: sampleType,
                quantity: bgQuantity,
                start: bgItem.dateString,
                end: bgItem.dateString,
                metadata: [
                    HKMetadataKeyExternalUUID: bgItem.id,
                    HKMetadataKeySyncIdentifier: bgItem.id,
                    HKMetadataKeySyncVersion: 1,
                    Config.freeAPSMetaKey: true
                ]
            )
            load(sampleFromHealth: sampleType, withID: bgItem.id) { [weak self] samples in
                if samples.isEmpty {
                    self?.healthKitStore.save(bgObjectSample) { _, _ in }
                }
            }
        }
    }

    func createObserver() {
        guard settingsManager.settings.useAppleHealth else { return }

        guard let bgType = Config.healthBGObject else {
            warning(
                .service,
                "Can not create HealthKit Observer, because unable to get the Blood Glucose type",
                description: nil,
                error: nil
            )
            return
        }

        let query = HKObserverQuery(sampleType: bgType, predicate: nil) { [unowned self] _, _, observerError in

            if let _ = observerError {
                return
            }

            // loading only daily bg
            let predicateByDate = HKQuery.predicateForSamples(
                withStart: Date().addingTimeInterval(-1.days.timeInterval),
                end: nil,
                options: .strictStartDate
            )

            // loading only not FreeAPS bg
            let predicateByMeta = HKQuery.predicateForObjects(
                withMetadataKey: Config.freeAPSMetaKey,
                operatorType: .notEqualTo,
                value: 1
            )
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicateByDate, predicateByMeta])

            healthKitStore.execute(getQueryForDeletedBloodGlucose(sampleType: bgType, predicate: compoundPredicate))
            healthKitStore.execute(getQueryForAddedBloodGlucose(sampleType: bgType, predicate: compoundPredicate))
        }
        healthKitStore.execute(query)
        debug(.service, "Create HealthKit Observer for Blood Glucose")
    }

    func enableBackgroundDelivery() {
        guard settingsManager.settings.useAppleHealth else { return }

        guard let bgType = Config.healthBGObject else {
            warning(
                .service,
                "Can not create HealthKit Background Delivery, because unable to get the Blood Glucose type",
                description: nil,
                error: nil
            )
            return
        }

        healthKitStore.enableBackgroundDelivery(
            for: bgType,
            frequency: Config.frequencyBackgroundDeliveryBloodGlucoseFromHealth
        ) { status, e in
            guard e == nil else {
                warning(.service, "Can not enable background delivery for Apple Health", description: nil, error: e)
                return
            }
            debug(.service, "HealthKit background delivery status is \(status)")
        }
    }

    /// Try to load samples from Health store with id and do some work
    private func load(
        sampleFromHealth sampleType: HKQuantityType,
        withID id: String,
        andDo completion: (([HKSample]) -> Void)?
    ) {
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeySyncIdentifier,
            operatorType: .equalTo,
            value: id
        )

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        ) { _, results, _ in

            guard let samples = results as? [HKQuantitySample] else {
                completion?([])
                return
            }

            completion?(samples)
        }
        healthKitStore.execute(query)
    }

    private var lastAnchorForLoadDeletedData: HKQueryAnchor!

    private func getQueryForDeletedBloodGlucose(sampleType: HKQuantityType, predicate: NSPredicate) -> HKQuery {
        let query = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: predicate,
            anchor: lastAnchorForLoadDeletedData,
            limit: HKObjectQueryNoLimit
        ) { [unowned self] _, _, deletedObjects, anchor, _ in
            guard let samples = deletedObjects, samples.isNotEmpty else {
                return
            }
            lastAnchorForLoadDeletedData = anchor

            DispatchQueue.global(qos: .utility).async {
                let removingBGID = samples.map {
                    $0.metadata?[HKMetadataKeySyncIdentifier] as? String ?? $0.uuid.uuidString
                }
                glucoseStorage.removeGlucose(ids: removingBGID)
                newGlucose = newGlucose.filter { !removingBGID.contains($0.id) }
            }
        }

        return query
    }

    private func getQueryForAddedBloodGlucose(sampleType: HKQuantityType, predicate: NSPredicate) -> HKQuery {
        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { [unowned self] _, results, _ in
            guard let samples = results as? [HKQuantitySample], samples.isNotEmpty else {
                return
            }

            let oldSamples: [HealthKitSample] = fileStorage
                .retrieve(OpenAPS.HealthKit.downloadedGlucose, as: [HealthKitSample].self) ?? []

            let newSamples = samples
                .compactMap { sample -> HealthKitSample? in
                    let fromFAX = sample.metadata?[Config.freeAPSMetaKey] as? Bool ?? false
                    guard !fromFAX else { return nil }
                    return HealthKitSample(
                        healthKitId: sample.uuid.uuidString,
                        date: sample.startDate,
                        glucose: Int(round(sample.quantity.doubleValue(for: .milligramsPerDeciliter)))
                    )
                }
                .filter { !oldSamples.contains($0) }

            guard newSamples.isNotEmpty else { return }

            let newGlucose = newSamples.map { sample in
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

            self.newGlucose = newGlucose

            let savingSamples = (newSamples + oldSamples)
                .removeDublicates()
                .filter { $0.date >= Date().addingTimeInterval(-1.days.timeInterval) }

            self.fileStorage.save(savingSamples, as: OpenAPS.HealthKit.downloadedGlucose)
        }
        return query
    }

    func fetch() -> AnyPublisher<[BloodGlucose], Never> {
        guard settingsManager.settings.useAppleHealth else { return Just([]).eraseToAnyPublisher() }
        let actualGlucose = newGlucose.filter { $0.dateString <= Date() }
        newGlucose = newGlucose.filter { !actualGlucose.contains($0) }
        return Just(actualGlucose).eraseToAnyPublisher()
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
