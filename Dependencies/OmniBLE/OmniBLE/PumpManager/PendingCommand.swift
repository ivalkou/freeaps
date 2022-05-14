//
//  PendingCommand.swift
//  OmniBLE
//
//  Created by Pete Schwamb on 1/18/22.
//  Copyright © 2022 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit


public enum StartProgram: RawRepresentable {
    public typealias RawValue = [String: Any]

    case bolus(volume: Double, automatic: Bool)
    case basalProgram(schedule: BasalSchedule)
    case tempBasal(unitsPerHour: Double, duration: TimeInterval, automatic: Bool, isHighTemp: Bool)
    
    private enum StartProgramType: Int {
        case bolus, basalProgram, tempBasal
    }
    
    public var rawValue: RawValue {
        switch self {
        case .bolus(let volume, let automatic):
            return [
                "programType": StartProgramType.bolus.rawValue,
                "volume": volume,
                "automatic": automatic
            ]
        case .basalProgram(let schedule):
            return [
                "programType": StartProgramType.basalProgram.rawValue,
                "schedule": schedule.rawValue
            ]
        case .tempBasal(let unitsPerHour, let duration, let automatic, let isHighTemp):
            return [
                "programType": StartProgramType.tempBasal.rawValue,
                "unitsPerHour": unitsPerHour,
                "duration": duration,
                "automatic": automatic,
                "isHighTemp": isHighTemp
            ]
        }
    }

    public init?(rawValue: RawValue) {
        guard let encodedTypeRaw = rawValue["programType"] as? StartProgramType.RawValue,
            let encodedType = StartProgramType(rawValue: encodedTypeRaw) else
        {
            return nil
        }
        switch encodedType {
        case .bolus:
            guard let volume = rawValue["volume"] as? Double,
                  let automatic = rawValue["automatic"] as? Bool else
            {
                return nil
            }
            self = .bolus(volume: volume, automatic: automatic)
        case .basalProgram:
            guard let rawSchedule = rawValue["schedule"] as? BasalSchedule.RawValue,
                  let schedule = BasalSchedule(rawValue: rawSchedule) else
            {
                return nil
            }
            self = .basalProgram(schedule: schedule)
        case .tempBasal:
            guard let unitsPerHour = rawValue["unitsPerHour"] as? Double,
                  let duration = rawValue["duration"] as? TimeInterval,
                  let automatic = rawValue["automatic"] as? Bool,
                  let isHighTemp = rawValue["isHighTemp"] as? Bool else
            {
                return nil
            }
            self = .tempBasal(unitsPerHour: unitsPerHour, duration: duration, automatic: automatic, isHighTemp: isHighTemp)
        }
    }
    
    public static func == (lhs: StartProgram, rhs: StartProgram) -> Bool {
        switch(lhs, rhs) {
        case (.bolus(let lhsVolume, let lhsAutomatic), .bolus(let rhsVolume, let rhsAutomatic)):
            return lhsVolume == rhsVolume && lhsAutomatic == rhsAutomatic
        case (.basalProgram(let lhsSchedule), .basalProgram(let rhsSchedule)):
            return lhsSchedule == rhsSchedule
        case (.tempBasal(let lhsUnitsPerHour, let lhsDuration, let lhsAutomatic, let lhsIsHighTemp), .tempBasal(let rhsUnitsPerHour, let rhsDuration, let rhsAutomatic, let rhsIsHighTemp)):
            return lhsUnitsPerHour == rhsUnitsPerHour && lhsDuration == rhsDuration && lhsAutomatic == rhsAutomatic && lhsIsHighTemp == rhsIsHighTemp
        default:
            return false
        }
    }
}

public enum PendingCommand: RawRepresentable, Equatable {
    public typealias RawValue = [String: Any]

    case program(StartProgram, Int, Date)
    case stopProgram(CancelDeliveryCommand.DeliveryType, Int, Date)
    
    private enum PendingCommandType: Int {
        case startProgram, stopProgram
    }
    
    public var commandDate: Date {
        switch self {
        case .program(_, _, let date):
            return date
        case .stopProgram(_, _, let date):
            return date
        }
    }

    public var sequence: Int {
        switch self {
        case .program(_, let sequence, _):
            return sequence
        case .stopProgram(_, let sequence, _):
            return sequence
        }
    }

    public init?(rawValue: RawValue) {
        guard let rawPendingCommandType = rawValue["type"] as? PendingCommandType.RawValue else {
            return nil
        }
        
        guard let commandDate = rawValue["date"] as? Date else {
            return nil
        }

        guard let sequence = rawValue["sequence"] as? Int else {
            return nil
        }


        switch PendingCommandType(rawValue: rawPendingCommandType) {
        case .startProgram?:
            guard let rawUnacknowledgedProgram = rawValue["unacknowledgedProgram"] as? StartProgram.RawValue else {
                return nil
            }
            if let program = StartProgram(rawValue: rawUnacknowledgedProgram) {
                self = .program(program, sequence, commandDate)
            } else {
                return nil
            }
        case .stopProgram?:
            guard let rawDeliveryType = rawValue["unacknowledgedStopProgram"] as? CancelDeliveryCommand.DeliveryType.RawValue else {
                return nil
            }
            let stopProgram = CancelDeliveryCommand.DeliveryType(rawValue: rawDeliveryType)
            self = .stopProgram(stopProgram, sequence, commandDate)
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [:]
        
        switch self {
        case .program(let program, let sequence, let date):
            rawValue["type"] = PendingCommandType.startProgram.rawValue
            rawValue["date"] = date
            rawValue["sequence"] = sequence
            rawValue["unacknowledgedProgram"] = program.rawValue
        case .stopProgram(let stopProgram, let sequence, let date):
            rawValue["type"] = PendingCommandType.stopProgram.rawValue
            rawValue["date"] = date
            rawValue["sequence"] = sequence
            rawValue["unacknowledgedStopProgram"] = stopProgram.rawValue
        }
        return rawValue
    }
    
    public static func == (lhs: PendingCommand, rhs: PendingCommand) -> Bool {
        switch(lhs, rhs) {
        case (.program(let lhsProgram, let lhsSequence, let lhsDate), .program(let rhsProgram, let rhsSequence, let rhsDate)):
            return lhsProgram == rhsProgram && lhsSequence == rhsSequence && lhsDate == rhsDate
        case (.stopProgram(let lhsStopProgram, let lhsSequence, let lhsDate), .stopProgram(let rhsStopProgram, let rhsSequence, let rhsDate)):
            return lhsStopProgram == rhsStopProgram && lhsSequence == rhsSequence && lhsDate == rhsDate
        default:
            return false
        }
    }
}

