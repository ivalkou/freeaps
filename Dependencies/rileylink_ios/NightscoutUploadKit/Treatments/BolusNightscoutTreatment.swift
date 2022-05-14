//
//  BolusNightscoutTreatment.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/10/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class BolusNightscoutTreatment: NightscoutTreatment {
    
    public enum BolusType: String {
        case Normal = "normal"
        case Square = "square"
        case DualWave = "dual"
    }

    let bolusType: BolusType
    let amount: Double
    let programmed: Double
    let unabsorbed: Double
    let duration: TimeInterval
    let carbs: Int
    let ratio: Double

    public init(timestamp: Date, enteredBy: String, bolusType: BolusType, amount: Double, programmed: Double, unabsorbed: Double, duration: TimeInterval, carbs: Int, ratio: Double, notes: String? = nil, id: String?) {
        self.bolusType = bolusType
        self.amount = amount
        self.programmed = programmed
        self.unabsorbed = unabsorbed
        self.duration = duration
        self.carbs = carbs
        self.ratio = ratio
        // Commenting out usage of surrogate ID until Nightscout supports it.
        super.init(timestamp: timestamp, enteredBy: enteredBy, notes: notes, /* id: id, */
                   eventType: (carbs > 0) ? "Meal Bolus" : "Correction Bolus")

    }

    override public var dictionaryRepresentation: [String: Any] {
        var rval = super.dictionaryRepresentation
        if carbs > 0 {
            rval["carbs"] = carbs
            rval["ratio"] = ratio
        }
        rval["type"] = bolusType.rawValue
        rval["insulin"] = amount
        rval["programmed"] = programmed
        rval["unabsorbed"] = unabsorbed
        rval["duration"] = duration.minutes
        return rval
    }
}
