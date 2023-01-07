//
//  PumpOpsSynchronousTests.swift
//  RileyLink
//
//  Created by Jaim Zuber on 2/21/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import XCTest

@testable import RileyLinkKit
@testable import MinimedKit
@testable import RileyLinkBLEKit

class PumpOpsSynchronousTests: XCTestCase {
    
    var sut: PumpOpsSession!
    var pumpSettings: PumpSettings!
    var pumpState: PumpState!
    var pumpID: String!
    var pumpRegion: PumpRegion!
    var pumpModel: PumpModel!
    var mockMessageSender: MockPumpMessageSender!

    let dateComponents2007 = DateComponents(calendar: Calendar.current, year: 2007, month: 1, day: 1)
    let dateComponents2017 = DateComponents(calendar: Calendar.current, year: 2017, month: 1, day: 1)
    
    let squareBolusDataLength = 26
    
    lazy var datePast2007: Date = {
        return self.dateComponents2017.date!.addingTimeInterval(TimeInterval(minutes:60))
    }()
    
    lazy var datePast2017: Date = {
        return self.dateComponents2017.date!.addingTimeInterval(TimeInterval(minutes:60))
    }()
    
    lazy var dateTimestamp2010: DateComponents = {
        self.createSquareBolusEvent2010().timestamp
    }()
    
    override func setUp() {
        super.setUp()
        
        pumpID = "350535"
        pumpRegion = .worldWide
        pumpModel = PumpModel.model523

        mockMessageSender = MockPumpMessageSender()
        
        setUpSUT()
    }
    
    /// Creates the System Under Test. This is needed because our SUT has dependencies injected through the constructor
    func setUpSUT() {
        pumpSettings = PumpSettings(pumpID: pumpID, pumpRegion: pumpRegion)
        pumpState = PumpState()
        pumpState.pumpModel = pumpModel
        pumpState.awakeUntil = Date(timeIntervalSinceNow: 100) // pump is awake
        
        sut = PumpOpsSession(settings: pumpSettings, pumpState: pumpState, messageSender: mockMessageSender, delegate: mockMessageSender)
    }
    
    /// Duplicates logic in setUp with a new PumpModel
    ///
    /// - Parameter newPumpModel: model of the pump to test
    func setUpTestWithPumpModel(_ newPumpModel: PumpModel) {
        pumpModel = newPumpModel
        setUpSUT()
    }
    
    func testShouldContinueIfTimestampBeforeStartDateNotEncountered() {
        let page = HistoryPage(events: [createBatteryEvent()])

        let (_, hasMoreEvents, _) = page.timestampedEvents(after: .distantPast, timeZone: pumpState.timeZone, model: pumpModel)
        
        XCTAssertTrue(hasMoreEvents)
    }
    
    func testShouldFinishIfTimestampBeforeStartDateEncountered() {
        let batteryEvent = createBatteryEvent()
        let page = HistoryPage(events: [batteryEvent])
        
        let afterBatteryEventDate = batteryEvent.timestamp.date!.addingTimeInterval(TimeInterval(hours: 10))
        
        let (_, hasMoreEvents, _) = page.timestampedEvents(after: afterBatteryEventDate, timeZone: pumpState.timeZone, model: pumpModel)
        
        XCTAssertFalse(hasMoreEvents)
    }

    func testEventsAfterStartDateAreReturned() {
        let batteryEvent2007 = createBatteryEvent(withDateComponent: dateComponents2007)
        let batteryEvent2017 = createBatteryEvent(withDateComponent: dateComponents2017)
        let page = HistoryPage(events: [batteryEvent2007, batteryEvent2017])
        
        let (events, _, _) = page.timestampedEvents(after: .distantPast, timeZone: pumpState.timeZone, model: pumpModel)
        
        XCTAssertEqual(events.count, 2)
    }

    func testEventBeforeStartDateIsFiltered() {
        let datePast2007 = dateComponents2007.date!.addingTimeInterval(TimeInterval(minutes: 60))
        
        let batteryEvent2007 = createBatteryEvent(withDateComponent: dateComponents2007)
        let batteryEvent2017 = createBatteryEvent(withDateComponent: dateComponents2017)
        let page = HistoryPage(events: [batteryEvent2007, batteryEvent2017])
        
        let (events, hasMoreEvents, cancelled) = page.timestampedEvents(after: datePast2007, timeZone: pumpState.timeZone, model: pumpModel)
        
        assertArray(events, doesntContainPumpEvent: batteryEvent2007)
        XCTAssertEqual(events.count, 1)
        XCTAssertFalse(hasMoreEvents)
        XCTAssertFalse(cancelled)
    }

    func testPumpLostTimeCancelsFetchEarly() {
        let batteryEvent2007 = createBatteryEvent(withDateComponent: dateComponents2007)
        let batteryEvent2017 = createBatteryEvent(withDateComponent: dateComponents2017)
        let page = HistoryPage(events: [batteryEvent2017, batteryEvent2007])

        let (events, hasMoreEvents, cancelledEarly) = page.timestampedEvents(after: Date.distantPast,  timeZone: pumpState.timeZone, model: pumpModel)

        XCTAssertTrue(cancelledEarly)
        XCTAssertFalse(hasMoreEvents)
        XCTAssertEqual(events.count, 1)
        assertArray(events, doesntContainPumpEvent: batteryEvent2017)
    }
    
    func testEventsWithSameDataArentAddedTwice() {
        let page = HistoryPage(events: [createBolusEvent2009(), createBolusEvent2009()])
        let (events, _, _) = page.timestampedEvents(after: Date.distantPast, timeZone: pumpState.timeZone, model: pumpModel)
        XCTAssertEqual(events.count, 1)
    }

    func testNonMutableSquareWaveBolusFor522IsReturned() {
        // device that can have out of order events
        setUpTestWithPumpModel(.model522)
        // 2009-07-31 09:00:00 +0000
        // 120 minute duration
        let squareWaveBolus = BolusNormalPumpEvent(availableData: Data(hexadecimalString: "010080048000240009a24a1510")!, pumpModel: pumpModel)!
        
        let page = HistoryPage(events: [squareWaveBolus])
        
        let (timeStampedEvents, _, _) = page.timestampedEvents(after: .distantPast, timeZone: pumpState.timeZone, model: pumpModel)
        
        // It should be included
        XCTAssertTrue(array(timeStampedEvents, containsPumpEvent: squareWaveBolus))
    }

    // This sets up a square wave bolus that has a timestamp four hours before a temp basal, but is appended to history
    // "after" the temp basal.  This is an important condition to test, because the temp basal could be filtered out erroneously
    // if we were just filtering on startDate, and startDate was after the bolus timestamp, but before the temp basal.
    // Previously, convertPumpEventToTimestampedEvents was being called with startDate: Date.distantPast
    // Changing it to use a time in that important window to cover
    func testDelayedAppendEventDoesNotCauseValidEventsToBeFilteredOut() {
        setUpTestWithPumpModel(.model522)

        let tempEventBasal = createTempEventBasal2016()
        let dateComponents = tempEventBasal.timestamp.addingTimeInterval(TimeInterval(hours:-4))
        let squareBolusEventFourHoursBefore = createSquareBolusEvent(dateComponents: dateComponents)
        
        let page = HistoryPage(events: [tempEventBasal, squareBolusEventFourHoursBefore])
        let (timeStampedEvents, hasMoreEvents, cancelled) = page.timestampedEvents(after: .distantPast, timeZone: pumpState.timeZone, model: pumpModel)

        // Debatable (undefined) whether this should be returned. It is tested to avoid inadvertantly changing behavior
        assertArray(timeStampedEvents, containsPumpEvent: squareBolusEventFourHoursBefore)
        XCTAssertTrue(hasMoreEvents)
        XCTAssertFalse(cancelled)
    }

    // MARK: Regular Bolus Event before starttime (offset 9 minutes)
    func test522RegularBolusEventBeforeStartTimeShouldNotCancel() {
        setUpTestWithPumpModel(.model522)
        
        let pumpEvent = createSquareBolusEvent2010()
        let page = HistoryPage(events: [pumpEvent])
        
        let startDate = pumpEvent.timestamp.date!.addingTimeInterval(TimeInterval(minutes:9))
        
        let (timestampedEvents, hasMoreEvents, cancelled) = page.timestampedEvents(after: startDate, timeZone: pumpState.timeZone, model: pumpModel)
        
        assertArray(timestampedEvents, containsPumpEvent: pumpEvent)
        //We found an event before the start time but we can't verify the timestamp from the Square Bolus so there could be more valid events
        XCTAssertTrue(hasMoreEvents)
        XCTAssertFalse(cancelled)
    }

    // The test the border condition sof the pump lost time detection, the main behavior of which is covered
    // in testPumpLostTimeCancelsFetchEarly. The precise point at which we decide pump time is lost (the one hour mark) is aribtrary.
    
    func testOutOfOrderEventUnderAnHourDoesntCancel() {
        setUpTestWithPumpModel(.model523)

        let after2007Date = dateComponents2007.date!.addingTimeInterval(TimeInterval(minutes:59))

        let batteryEvent = createBatteryEvent(withDateComponent: dateComponents2007)
        let laterBatteryEvent = createBatteryEvent(atTime: after2007Date)

        let page = HistoryPage(events: [laterBatteryEvent, batteryEvent])

        let (_, _, cancelled) = page.timestampedEvents(after: .distantPast, timeZone: pumpState.timeZone, model: pumpModel)

        XCTAssertFalse(cancelled)
    }

    // MARK: Test Sanity Checks
    func test2010EventSanityWith523() {
        setUpTestWithPumpModel(.model523)
        let bolusEvent = createSquareBolusEvent2010()
        XCTAssertEqual(bolusEvent.timestamp.year!, 2010)
        XCTAssertEqual(bolusEvent.timestamp.timeZone, pumpState.timeZone)
    }
    
    func test2009EventSanityWith523() {
        setUpTestWithPumpModel(.model523)
        let bolusEvent = createBolusEvent2009()
        XCTAssertEqual(bolusEvent.timestamp.year!, 2009)
        XCTAssertEqual(bolusEvent.timestamp.timeZone, pumpState.timeZone)
    }
    
    func test2009EventSavityWith522() {
        setUpTestWithPumpModel(.model522)
        XCTAssertEqual(createBolusEvent2009().timestamp.year!, 2009)
    }
    
    func test2010EventSanityWith522() {
        setUpTestWithPumpModel(.model522)
        XCTAssertEqual(createSquareBolusEvent2010().timestamp.year!, 2010)
    }

    func createBatteryEvent(withDateComponent dateComponents: DateComponents) -> BatteryPumpEvent {
        return createBatteryEvent(atTime: dateComponents.date!)
    }
    
    func createBatteryEvent(atTime date: Date = Date()) -> BatteryPumpEvent {
     
        let calendar = Calendar.current
        
        let year = calendar.component(.year, from: date) - 2000
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        
        let secondByte = UInt8(second) & 0b00111111
        let minuteByte = UInt8(minute) & 0b00111111
        let hourByte = UInt8(hour) & 0b00011111
        let dayByte = UInt8(day) & 0b00011111
        let monthUpperComponent = (UInt8(month) & 0b00001100) << 4
        let monthLowerComponent = (UInt8(month) & 0b00000011) << 6
        let secondMonthByte = secondByte | monthUpperComponent
        let minuteMonthByte = minuteByte | monthLowerComponent
        let yearByte = UInt8(year) & 0b01111111

        let batteryData = Data([0,0, secondMonthByte, minuteMonthByte, hourByte, dayByte, yearByte])
        let batteryPumpEvent = BatteryPumpEvent(availableData: batteryData, pumpModel: PumpModel.model523)!
        return batteryPumpEvent
    }
    
    func createSquareBolusEvent2010() -> BolusNormalPumpEvent {
        //2010-08-01 05:00:16 +000
        let dateComponents = DateComponents(calendar: Calendar.current, timeZone: pumpState.timeZone, year: 2010, month: 8, day: 1, hour: 5, minute: 0, second: 16)
        let data = Data(hexadecimalString: "01009000900058008a344b1010")!
        return BolusNormalPumpEvent(length: BolusNormalPumpEvent.calculateLength(pumpModel.larger), rawData: data, timestamp: dateComponents, unabsorbedInsulinRecord: nil, amount: 0.0, programmed: 0.0, unabsorbedInsulinTotal: 0.0, type: .square, duration: TimeInterval(minutes: 120), wasRemotelyTriggered: false)
    }
    
    func createSquareBolusEvent(dateComponents: DateComponents) -> BolusNormalPumpEvent {
        let data = Data(hexadecimalString: randomDataString(length: squareBolusDataLength))!
        return BolusNormalPumpEvent(length: BolusNormalPumpEvent.calculateLength(pumpModel.larger), rawData: data, timestamp: dateComponents, unabsorbedInsulinRecord: nil, amount: 0.0, programmed: 0.0, unabsorbedInsulinTotal: 0.0, type: .square, duration: TimeInterval(hours: 8), wasRemotelyTriggered: false)
    }
    
    func createBolusEvent2011() -> BolusNormalPumpEvent {
        //2010-08-01 05:00:11 +000
        let dateComponents = DateComponents(calendar: Calendar.current, timeZone: pumpState.timeZone, year: 2011, month: 8, day: 1, hour: 5, minute: 0, second: 16)
        let data = Data(hexadecimalString: "01009000900058008a344b10FF")!
        return BolusNormalPumpEvent(length: BolusNormalPumpEvent.calculateLength(pumpModel.larger), rawData: data, timestamp: dateComponents, unabsorbedInsulinRecord: nil, amount: 0.0, programmed: 0.0, unabsorbedInsulinTotal: 0.0, type: .normal, duration: TimeInterval(minutes: 120), wasRemotelyTriggered: false)
    }
    
    func createTempEventBasal2016() -> TempBasalPumpEvent {
        // 2016-05-30 01:21:00 +0000
        let tempEventBasal = TempBasalPumpEvent(availableData: Data(hexadecimalString:"338c4055145d1000")!, pumpModel: pumpModel)!
        return tempEventBasal
    }
    
    func createBolusEvent2009() -> BolusNormalPumpEvent {
        
        let dateComponents = DateComponents(calendar: Calendar.current, timeZone: pumpState.timeZone, year: 2009, month: 7, day: 31, hour: 9, minute: 0, second: 0)
        let timeInterval: TimeInterval = TimeInterval(minutes: 2)
        let data = Data(hexadecimalString:"338c4055145d2000")!
        
        return BolusNormalPumpEvent(length: 13, rawData: data, timestamp: dateComponents, unabsorbedInsulinRecord: nil, amount: 2.0, programmed: 1.0, unabsorbedInsulinTotal: 0.0, type: .normal, duration: timeInterval, wasRemotelyTriggered: false)
    }
    
    func createNonDelayedEvent2009() -> BolusReminderPumpEvent {
        let dateComponents = DateComponents(calendar: Calendar.current, timeZone: pumpState.timeZone, year: 2009, month: 7, day: 31, hour: 9, minute: 0, second: 0)
        let data = Data(hexadecimalString:"338c48FFF45d2000")!
        let length = 7
        
        return BolusReminderPumpEvent(length: length, rawData: data, timestamp: dateComponents)
    }
}

// from comment at https://gist.github.com/szhernovoy/276e69eb90a0de84dd90
func randomDataString(length:Int) -> String {
    let charSet = "abcdef0123456789"
    let c = charSet.map { String($0) }
    var s:String = ""
    for _ in 0..<length {
        s.append(c[Int(arc4random()) % c.count])
    }
    return s
}

class MockPumpMessageSender: PumpMessageSender {

    func listenForPacket(onChannel channel: Int, timeout: TimeInterval) throws -> RileyLinkBLEKit.RFPacket? {
        // do nothing
        return nil
    }

    func getRileyLinkStatistics() throws -> RileyLinkStatistics {
        throw PumpOpsError.noResponse(during: "Tests")
    }
    
    func sendAndListen(_ data: Data, repeatCount: Int, timeout: TimeInterval, retryCount: Int) throws -> RFPacket {
        guard let decoded = MinimedPacket(encodedData: data),
              let messageType = MessageType(rawValue: decoded.data[4])
        else {
            throw PumpOpsError.noResponse(during: "Tests")
        }

        let response: PumpMessage

        if let responseArray = responses[messageType] {
            let numberOfResponsesReceived: Int

            if let someValue = responsesHaveOccured[messageType] {
                numberOfResponsesReceived = someValue
            } else {
                numberOfResponsesReceived = 0
            }

            let nextNumberOfResponsesReceived = numberOfResponsesReceived + 1
            responsesHaveOccured[messageType] = nextNumberOfResponsesReceived

            if numberOfResponsesReceived >= responseArray.count {
                XCTFail()
            }

            response = responseArray[numberOfResponsesReceived]
        } else {
            let packet = MinimedPacket(encodedData: Data(hexadecimalString: "a969a39966b1566555b235")!)!
            response = PumpMessage(rxData: packet.data)!
        }

        var encoded = MinimedPacket(outgoingData: response.txData).encodedData()
        encoded.insert(contentsOf: [0, 0], at: 0)
        
        guard let rfPacket = RFPacket(rfspyResponse: encoded) else {
            throw PumpOpsError.noResponse(during: data)
        }

        return rfPacket
    }

    func getResponse<T: MessageBody>(to message: PumpMessage, responseType: MessageType, repeatCount: Int, timeout: TimeInterval, retryCount: Int) throws -> T {

        let response = try sendAndListen(message, repeatCount: repeatCount, timeout: timeout, retryCount: retryCount)

        guard response.messageType == responseType, let body = response.messageBody as? T else {
            if let body = response.messageBody as? PumpErrorMessageBody {
                switch body.errorCode {
                case .known(let code):
                    throw PumpOpsError.pumpError(code)
                case .unknown(let code):
                    throw PumpOpsError.unknownPumpErrorCode(code)
                }
            } else {
                throw PumpOpsError.unexpectedResponse(response, from: message)
            }
        }
        return body
    }

    /// Sends a message to the pump, listening for a any known PumpMessage in reply
    ///
    /// - Parameters:
    ///   - message: The message to send
    ///   - repeatCount: The number of times to repeat the message before listening begins
    ///   - timeout: The length of time to listen for a pump response
    ///   - retryCount: The number of times to repeat the send & listen sequence
    /// - Returns: The message reply
    /// - Throws: An error describing a failure in the sending or receiving of a message:
    ///     - PumpOpsError.couldNotDecode
    ///     - PumpOpsError.crosstalk
    ///     - PumpOpsError.deviceError
    ///     - PumpOpsError.noResponse
    ///     - PumpOpsError.unknownResponse
    func sendAndListen(_ message: PumpMessage, repeatCount: Int, timeout: TimeInterval, retryCount: Int) throws -> PumpMessage {
        let rfPacket = try sendAndListenForPacket(message, repeatCount: repeatCount, timeout: timeout, retryCount: retryCount)

        guard let packet = MinimedPacket(encodedData: rfPacket.data) else {
            throw PumpOpsError.couldNotDecode(rx: rfPacket.data, during: message)
        }

        guard let response = PumpMessage(rxData: packet.data) else {
            // Unknown packet type or message type
            throw PumpOpsError.unknownResponse(rx: packet.data, during: message)
        }

        guard response.address == message.address else {
            throw PumpOpsError.crosstalk(response, during: message)
        }

        return response
    }

    // Send a PumpMessage, and listens for a packet; used by callers who need to see RSSI
    /// - Throws:
    ///     - PumpOpsError.noResponse
    ///     - PumpOpsError.deviceError
    func sendAndListenForPacket(_ message: PumpMessage, repeatCount: Int, timeout: TimeInterval, retryCount: Int) throws -> RFPacket {
        let packet: RFPacket?

        do {
            packet = try sendAndListen(MinimedPacket(outgoingData: message.txData).encodedData(), repeatCount: repeatCount, timeout: timeout, retryCount: retryCount)
        } catch let error as LocalizedError {
            throw PumpOpsError.deviceError(error)
        }

        guard let rfPacket = packet else {
            throw PumpOpsError.noResponse(during: message)
        }

        return rfPacket
    }

    func listen(onChannel channel: Int, timeout: TimeInterval) throws -> RFPacket? {
        throw PumpOpsError.noResponse(during: "Tests")
    }

    func send(_ msg: MinimedKit.PumpMessage) throws {
        // Do nothing
    }

    func updateRegister(_ address: CC111XRegister, value: UInt8) throws {
        throw PumpOpsError.noResponse(during: "Tests")
    }
    
    func resetRadioConfig() throws {
        throw PumpOpsError.noResponse(during: "Tests")
    }

    func setBaseFrequency(_ frequency: Measurement<UnitFrequency>) throws {
        throw PumpOpsError.noResponse(during: "Tests")
    }
    
    var responses = [MessageType: [PumpMessage]]()
    
    // internal tracking of how many times a response type has been received
    private var responsesHaveOccured = [MessageType: Int]()
}

extension MockPumpMessageSender: PumpOpsSessionDelegate {
    func pumpOpsSession(_ session: PumpOpsSession, didChange state: PumpState) {

    }
    
    func pumpOpsSessionDidChangeRadioConfig(_ session: PumpOpsSession) {
        
    }

}

func array(_ timestampedEvents: [TimestampedHistoryEvent], containsPumpEvent pumpEvent: PumpEvent) -> Bool {
    let event = timestampedEvents.first { $0.pumpEvent.rawData == pumpEvent.rawData }
    
    return event != nil
}

func assertArray(_ timestampedEvents: [TimestampedHistoryEvent], containsPumpEvent pumpEvent: PumpEvent) {
    XCTAssertNotNil(timestampedEvents.first { $0.pumpEvent.rawData == pumpEvent.rawData})
}

func assertArray(_ timestampedEvents: [TimestampedHistoryEvent], containsPumpEvents pumpEvents: [PumpEvent]) {
    pumpEvents.forEach { assertArray(timestampedEvents, containsPumpEvent: $0) }
}

func assertArray(_ timestampedEvents: [TimestampedHistoryEvent], doesntContainPumpEvent pumpEvent: PumpEvent) {
    XCTAssertNil(timestampedEvents.first { $0.pumpEvent.rawData == pumpEvent.rawData })
}

// from http://jernejstrasner.com/2015/07/08/testing-throwable-methods-in-swift-2.html - transferred to Swift 3
func assertThrows<T>(_ expression: @autoclosure  () throws -> T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    do {
        let _ = try expression()
        XCTFail("No error to catch! - \(message)", file: file, line: line)
    } catch {
    }
}

func assertNoThrow<T>(_ expression: @autoclosure  () throws -> T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    do {
        let _ = try expression()
    } catch let error {
        XCTFail("Caught error: \(error) - \(message)", file: file, line: line)
    }
}

extension DateComponents {
    func addingTimeInterval(_ timeInterval: TimeInterval) -> DateComponents {
        let newDate = self.date!.addingTimeInterval(timeInterval)
        let newDateComponents = Calendar.current.dateComponents(in: TimeZone.currentFixed, from: newDate)
        return newDateComponents
    }
}
