//
//  ShareClientManager.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKit
import HealthKit


public class ShareClientManager: CGMManager {
    public static var managerIdentifier = "DexShareClient"

    public init() {
        shareService = ShareService(keychainManager: keychain)
    }

    required convenience public init?(rawState: CGMManager.RawStateValue) {
        self.init()
    }

    public var rawState: CGMManager.RawStateValue {
        return [:]
    }

    private let keychain = KeychainManager()

    public var shareService: ShareService {
        didSet {
            try! keychain.setDexcomShareUsername(shareService.username, password: shareService.password, url: shareService.url)
        }
    }

    public static let localizedTitle = LocalizedString("Dexcom Share", comment: "Title for the CGMManager option")

    public let appURL: URL? = nil

    public var cgmManagerDelegate: CGMManagerDelegate? {
        get {
            return delegate.delegate
        }
        set {
            delegate.delegate = newValue
        }
    }

    public var delegateQueue: DispatchQueue! {
        get {
            return delegate.queue
        }
        set {
            delegate.queue = newValue
        }
    }

    public let delegate = WeakSynchronizedDelegate<CGMManagerDelegate>()

    public let providesBLEHeartbeat = false

    public let shouldSyncToRemoteService = false

    public var sensorState: SensorDisplayable? {
        return latestBackfill
    }

    public let managedDataInterval: TimeInterval? = nil

    public private(set) var latestBackfill: ShareGlucose?

    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) {
        guard let shareClient = shareService.client else {
            completion(.noData)
            return
        }

        // If our last glucose was less than 4.5 minutes ago, don't fetch.
        if let latestGlucose = latestBackfill, latestGlucose.startDate.timeIntervalSinceNow > -TimeInterval(minutes: 4.5) {
            completion(.noData)
            return
        }

        shareClient.fetchLast(6) { (error, glucose) in
            if let error = error {
                completion(.error(error))
                return
            }
            guard let glucose = glucose else {
                completion(.noData)
                return
            }

            // Ignore glucose values that are up to a minute newer than our previous value, to account for possible time shifting in Share data
            let startDate = self.delegate.call { (delegate) -> Date? in
                return delegate?.startDateToFilterNewData(for: self)?.addingTimeInterval(TimeInterval(minutes: 1))
            }
            let newGlucose = glucose.filterDateRange(startDate, nil)
            let newSamples = newGlucose.filter({ $0.isStateValid }).map {
                return NewGlucoseSample(date: $0.startDate, quantity: $0.quantity, isDisplayOnly: false, syncIdentifier: "\(Int($0.startDate.timeIntervalSince1970))", device: self.device)
            }

            self.latestBackfill = newGlucose.first

            if newSamples.count > 0 {
                completion(.newData(newSamples))
            } else {
                completion(.noData)
            }
        }
    }

    public var device: HKDevice? = nil

    public var debugDescription: String {
        return [
            "## ShareClientManager",
            "latestBackfill: \(String(describing: latestBackfill))",
            ""
        ].joined(separator: "\n")
    }
}
