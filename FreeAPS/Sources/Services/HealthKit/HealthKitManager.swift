import Foundation
import HealthKit

protocol HealthKitManager {
    /// Storage of HealthKit
    var store: HKHealthStore { get }
    /// Check availability HealthKit on current device and user's permissions
    var isAvailableOnCurrentDevice: Bool { get }
    /// Check availability HealthKit on current device and user's permission of object
    func isAvailableFor(object: HKObjectType) -> Bool
    /// Requests user to give permissions on using HealthKit
    func requestPermission(completion: ((Bool, Error?) -> Void)?)
    /// Check status of request for permission to write/read HealthKit storage
    func checkRequestPermissionStatus(completion: ((Result<HealthKitPermissionRequestStatus, HKError>?) -> Void)?)
}

enum HealthKitPermissionRequestStatus {
    case needRequest
    case didRequest
}

final class BaseHealthKitManager: HealthKitManager {
    private enum Config {
        static let permissions = Set([HKObjectType.quantityType(forIdentifier: .bloodGlucose)!])
    }

    

    // App must have only one Health Store
    private static var _store = HKHealthStore()
    var store: HKHealthStore {
        Self._store
    }

    var isAvailableOnCurrentDevice: Bool {
        HKHealthStore.isHealthDataAvailable()
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

    func checkRequestPermissionStatus(completion: ((Result<HealthKitPermissionRequestStatus, HKError>?) -> Void)? = nil) {
        store.getRequestStatusForAuthorization(toShare: Config.permissions, read: Config.permissions, completion: { status, error in
            guard error == nil else {
                completion?(Result.failure(.error(error)))
                return
            }
            guard status != .unknown else {
                completion?(Result.failure(.unknown))
                return
            }
            if status == .shouldRequest {
                completion?(Result.success(.needRequest))
                return
            } else if status == .unnecessary {
                completion?(Result.success(.didRequest))
            }
        })
    }

    func requestPermission(completion: ((Bool, Error?) -> Void)? = nil) {
        guard isAvailableOnCurrentDevice else {
            completion?(false, HKError.notAvailableOnCurrentDevice)
            return
        }

        store.requestAuthorization(toShare: Config.permissions, read: Config.permissions) { status, error in
            completion?(status, error)
        }
    }
}

enum HKError: Error {
    case notAvailableOnCurrentDevice
    case unknown
    case error(Error?)
}
