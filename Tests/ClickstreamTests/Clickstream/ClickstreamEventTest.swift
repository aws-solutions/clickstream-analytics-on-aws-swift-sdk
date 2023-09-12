//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

@testable import Clickstream
import Foundation
import XCTest
class ClickstreamEventTest: XCTestCase {
    let testAppId = "testAppId"
    let storage = ClickstreamContextStorage(userDefaults: UserDefaults.standard)
    var clickstreamEvent: ClickstreamEvent!
    override func setUp() {
        clickstreamEvent = ClickstreamEvent(eventType: "testEvent",
                                            appId: testAppId,
                                            uniqueId: UUID().uuidString,
                                            session: Session(uniqueId: UUID().uuidString, sessionIndex: 1),
                                            systemInfo: SystemInfo(storage: storage),
                                            netWorkType: NetWorkType.Wifi)
    }

    override func tearDown() {
        clickstreamEvent = nil
    }

    func testAddAttributeSuccess() {
        clickstreamEvent.addAttribute(133_232_123, forKey: "GoodsId")
        clickstreamEvent.addAttribute("iPhone 14", forKey: "GoodsName")
        clickstreamEvent.addAttribute(true, forKey: "isNewGoods")
        XCTAssertEqual(133_232_123, clickstreamEvent.attribute(forKey: "GoodsId") as! Int)
        XCTAssertEqual("iPhone 14", clickstreamEvent.attribute(forKey: "GoodsName") as! String)
        XCTAssertEqual(true, clickstreamEvent.attribute(forKey: "isNewGoods") as! Bool)
    }

    func testAddAttributeErrorForInvalidKey() {
        clickstreamEvent.addAttribute(133_232_123, forKey: "1GoodsId")
        XCTAssertNil(clickstreamEvent.attribute(forKey: "isNewGoods"))
        let errorCode = clickstreamEvent.attribute(forKey: Event.ReservedAttribute.ERROR_CODE) as! Int
        let errorValueString = clickstreamEvent.attribute(forKey: Event.ReservedAttribute.ERROR_MESSAGE) as! String
        XCTAssertEqual(Event.ErrorCode.ATTRIBUTE_NAME_INVALID, errorCode)
        XCTAssertTrue(errorValueString.contains("1GoodsId"))
    }

    func testAddAttributeErrorForExceedMaxLenthOfKey() {
        let longAttributeKey = String(repeating: "a", count: 51)
        clickstreamEvent.addAttribute("testValue", forKey: longAttributeKey)
        XCTAssertNil(clickstreamEvent.attribute(forKey: "longAttributeKey"))
        let errorCode = clickstreamEvent.attribute(forKey: Event.ReservedAttribute.ERROR_CODE) as! Int
        let errorValueString = clickstreamEvent.attribute(forKey: Event.ReservedAttribute.ERROR_MESSAGE) as! String
        XCTAssertEqual(Event.ErrorCode.ATTRIBUTE_NAME_LENGTH_EXCEED, errorCode)
        XCTAssertTrue(errorValueString.contains(longAttributeKey))
    }

    func testAddAttributeErrorForExceedMaxLenthOfValue() {
        let longAttributeValue = String(repeating: "a", count: 1_025)
        clickstreamEvent.addAttribute(longAttributeValue, forKey: "testKey")
        XCTAssertNil(clickstreamEvent.attribute(forKey: "testKey"))
        let errorCode = clickstreamEvent.attribute(forKey: Event.ReservedAttribute.ERROR_CODE) as! Int
        let errorValueString = clickstreamEvent.attribute(forKey: Event.ReservedAttribute.ERROR_MESSAGE) as! String
        XCTAssertEqual(Event.ErrorCode.ATTRIBUTE_VALUE_LENGTH_EXCEED, errorCode)
        XCTAssertTrue(errorValueString.contains("testKey"))
    }

    func testEventEqualsFail() {
        let event1 = clickstreamEvent
        let event2 = ClickstreamEvent(eventType: "testEvent",
                                      appId: testAppId,
                                      uniqueId: UUID().uuidString,
                                      session: Session(uniqueId: UUID().uuidString, sessionIndex: 1),
                                      systemInfo: SystemInfo(storage: storage),
                                      netWorkType: NetWorkType.Wifi)
        XCTAssertFalse(event1 == event2)
    }
}
