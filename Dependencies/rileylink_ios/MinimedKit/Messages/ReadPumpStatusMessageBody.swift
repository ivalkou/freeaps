//
//  ReadPumpStatusMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/31/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class ReadPumpStatusMessageBody: DecodableMessageBody {

    public static var length: Int = 65

    public var txData: Data

    public let bolusing: Bool
    public let suspended: Bool

    public required init?(rxData: Data) {
        guard rxData.count == type(of: self).length else {
            return nil
        }

        bolusing = rxData[2] > 0
        suspended = rxData[3] > 0
        self.txData = rxData
    }

    public var description: String {
        return "ReadPumpStatus(bolusing:\(bolusing), suspended:\(suspended))"
    }
}
