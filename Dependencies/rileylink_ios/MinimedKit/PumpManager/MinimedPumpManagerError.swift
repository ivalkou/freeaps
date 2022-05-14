//
//  MinimedPumpManagerError.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation

public enum MinimedPumpManagerError: Error {
    case noRileyLink
    case bolusInProgress
    case noDate  // TODO: This is less of an error and more of a precondition/assertion state
    case tuneFailed(LocalizedError)
}


extension MinimedPumpManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noRileyLink:
            return nil
        case .bolusInProgress:
            return nil
        case .noDate:
            return nil
        case .tuneFailed(let error):
            return [LocalizedString("RileyLink radio tune failed", comment: "Error description"), error.errorDescription].compactMap({ $0 }).joined(separator: ": ")
        }
    }

    public var failureReason: String? {
        switch self {
        case .noRileyLink:
            return nil
        case .bolusInProgress:
            return nil
        case .noDate:
            return nil
        case .tuneFailed(let error):
            return error.failureReason
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noRileyLink:
            return LocalizedString("Make sure your RileyLink is nearby and powered on", comment: "Recovery suggestion")
        case .bolusInProgress:
            return nil
        case .noDate:
            return nil
        case .tuneFailed(let error):
            return error.recoverySuggestion
        }
    }
}
