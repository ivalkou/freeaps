import Foundation
import HealthKit
import Swinject

protocol HealthKitManager {
    /// Storage of HealthKit
    var store: HKHealthStore { get }
    /// Check availability HealthKit on current device and user's permissions
    var isAvailableOnCurrentDevice: Bool { get }
    /// Check all needed permissions
    /// Return false if one or more permissions are deny or not choosen
    var areAllowAllPermissions: Bool { get }
    /// Check availability HealthKit on current device and user's permission of object
    func isAvailableFor(object: HKObjectType) -> Bool
    /// Requests user to give permissions on using HealthKit
    func requestPermission(completion: ((Bool, Error?) -> Void)?)
    /// Save blood glucose data to HealthKit store
    func save(bloodGlucoses: [BloodGlucose], completion: ((Result<Bool, Error>) -> Void)?)
}

final class BaseHealthKitManager: HealthKitManager, Injectable {
    @Injected() private var fileStorage: FileStorage!

    private enum Config {
        // unwraped HKObjects
        static var permissions: Set<HKSampleType> {
            var result: Set<HKSampleType> = []
            for permission in optionalPermissions {
                result.insert(permission!)
            }
            return result
        }

        static let optionalPermissions = Set([Config.HealthBGObject])
        // link to object in HealthKit
        static let HealthBGObject = HKObjectType.quantityType(forIdentifier: .bloodGlucose)
    }

    // App must have only one HealthKit Store
    private static var _store = HKHealthStore()
    var store: HKHealthStore {
        Self._store
    }

    var isAvailableOnCurrentDevice: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var areAllowAllPermissions: Bool {
        var result = true
        Config.permissions.forEach { permission in
            if [HKAuthorizationStatus.sharingDenied, HKAuthorizationStatus.notDetermined]
                .contains(store.authorizationStatus(for: permission))
            {
                result = false
            }
        }
        return result
    }

    init(resolver: Resolver) {
        injectServices(resolver)
        guard isAvailableOnCurrentDevice, let bjObject = Config.HealthBGObject else {
            return
        }
        if isAvailableFor(object: bjObject) {
            debug(.service, "Create HealthKit Observer for Blood Glucose")
            createObserver()
        }
    }

    func isAvailableFor(object: HKObjectType) -> Bool {
        let status = store.authorizationStatus(for: object)
        switch status {
        case HKAuthorizationStatus.sharingAuthorized:
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

        store.requestAuthorization(toShare: Config.permissions, read: Config.permissions) { status, error in
            completion?(status, error)
        }
    }

    func save(bloodGlucoses: [BloodGlucose], completion: ((Result<Bool, Error>) -> Void)? = nil) {
        for bgItem in bloodGlucoses {
            let bgQuantity = HKQuantity(
                unit: .milligramsPerDeciliter,
                doubleValue: Double(bgItem.glucose!)
            )

            let bjObjectSample = HKQuantitySample(
                type: Config.HealthBGObject!,
                quantity: bgQuantity,
                start: bgItem.dateString,
                end: bgItem.dateString,
                metadata: [
                    "HKMetadataKeyExternalUUID": bgItem.id,
                    "didSyncWithFreeAPSX": true
                ]
            )

            store.save(bjObjectSample) { status, error in
                guard error == nil else {
                    completion?(Result.failure(error!))
                    return
                }
                completion?(Result.success(status))
            }
        }
    }

    func createObserver() {
        guard let bgType = Config.HealthBGObject else {
            fatalError("*** Unable to get the Blood Glucose type ***")
        }

        let query = HKObserverQuery(sampleType: bgType, predicate: nil) { _, _, observerError in

            if let _ = observerError {
                return
            }

            let query = HKSampleQuery(
                sampleType: bgType,
                predicate: nil,
                limit: Int(HKObjectQueryNoLimit),
                sortDescriptors: nil
            ) { _, results, _ in

                guard let samples = results as? [HKQuantitySample] else {
                    return
                }

                var result = [HealthKitSample]()
                for sample in samples {
                    if sample.wasUserEntered {
                        result.append(HealthKitSample(healthKitId: sample.uuid.uuidString))
                    }
                }
                self.fileStorage.save(result, as: OpenAPS.HealthKit.downloadedGlucose)
            }
            self.store.execute(query)
        }
        store.execute(query)
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
