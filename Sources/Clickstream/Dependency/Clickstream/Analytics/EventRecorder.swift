//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import Foundation
#if canImport(UIKit)
    import UIKit
#endif

/// AnalyticsEventRecording saves and submits clickstream events
protocol AnalyticsEventRecording {
    /// Saves a clickstream event to storage
    /// - Parameter event: A ClickstreamEvent
    func save(_ event: ClickstreamEvent) throws

    /// Submit locally stored events
    /// - Parameter inBackgroundMode: wheter use background mode to send request
    func submitEvents(inBackgroundMode: Bool)
}

/// An AnalyticsEventRecording implementation that stores and submits clickstream events
class EventRecorder: AnalyticsEventRecording {
    var clickstream: ClickstreamContext
    let dbUtil: ClickstreamDBProtocol
    private(set) var queue: OperationQueue
    private(set) var bundleSequenceId: Int

    init(clickstream: ClickstreamContext) throws {
        self.clickstream = clickstream
        let dbAdapter = try BaseDBAdapter(prefixPath: Constants.dbPathPrefix,
                                          databaseName: clickstream.configuration.appId)
        self.dbUtil = ClickstreamDBUtil(dbAdapter: dbAdapter)
        try dbUtil.createTable()
        self.queue = OperationQueue()
        queue.maxConcurrentOperationCount = Constants.maxConcurrentOperations
        self.bundleSequenceId = UserDefaultsUtil.getBundleSequenceId(storage: clickstream.storage)
    }

    /// save an clickstream event to storage
    /// - Parameter event: A ClickstreamEvent
    func save(_ event: ClickstreamEvent) throws {
        let eventJson: String = event.toJson()
        let eventSize = eventJson.count
        let storageEvent = StorageEvent(eventJson: eventJson, eventSize: Int64(eventSize))
        try dbUtil.saveEvent(storageEvent)
        if clickstream.configuration.isLogEvents {
            setLogLevel(logLevel: LogLevel.debug)
            logEventPrettier(event: event)
        }
        while try dbUtil.getTotalSize() > Constants.maxDbSize {
            let events = try dbUtil.getEventsWith(limit: 5)
            for event in events {
                try dbUtil.deleteEvent(eventId: event.id!)
                if try dbUtil.getTotalSize() < Constants.maxDbSize {
                    break
                }
            }
        }
    }

    /// submit an batch events, add the processEvent() as operation into queue
    func submitEvents(inBackgroundMode: Bool = false) {
        if queue.operationCount < Constants.maxEventOperations {
            let operation = BlockOperation { [weak self] in
                var taskId: UIBackgroundTaskIdentifier?
                if inBackgroundMode {
                    taskId = self?.startBackgroundTask()
                }
                _ = self?.processEvent()
                if inBackgroundMode, taskId != nil {
                    self?.endBackgroundTask(taskId: taskId!)
                }
            }
            queue.addOperation(operation)
        } else {
            log.error("submit events ignored, exceed the operation queue max limit")
        }
    }

    /// process an batch event and send the events to server
    func processEvent() -> Int {
        let startTime = Date().millisecondsSince1970
        var submissions = 0
        var totalEventSend = 0
        do {
            if try dbUtil.getEventCount() == 0 {
                return totalEventSend
            }
            log.debug("Start flushing events")
            repeat {
                let batchEvent = try getBatchEvent()
                if batchEvent.eventCount == 0 {
                    break
                }
                let result = NetRequest.uploadEventWithURLSession(
                    eventsJson: batchEvent.eventsJson,
                    configuration: clickstream.configuration,
                    bundleSequenceId: bundleSequenceId)
                bundleSequenceId += 1
                UserDefaultsUtil.saveBundleSequenceId(storage: clickstream.storage, bundleSequenceId: bundleSequenceId)
                if !result {
                    break
                }
                try dbUtil.deleteBatchEvents(lastEventId: batchEvent.lastEventId)
                log.debug("Send \(batchEvent.eventCount) events")
                totalEventSend += batchEvent.eventCount
                submissions += 1
            } while submissions < Constants.maxSubmissionsAllowed
            let costTime = String(describing: Date().millisecondsSince1970 - startTime)
            log.info("Time of process event cost: \(costTime)ms")
        } catch {
            log.error("Failed to send event:\(error)")
        }
        return totalEventSend
    }

    func getBatchEvent() throws -> BatchEvent {
        var eventsJson = "["
        var eventCount = 0
        var lastEventId: Int64 = -1

        let events = try dbUtil.getEventsWith(limit: Constants.maxEventNumberOfBatch)
        for event in events {
            let eventJson = event.eventJson
            if eventsJson.count + eventJson.count > Constants.maxSubmissionSize {
                eventsJson.append("]")
                break
            } else if eventCount > 0 {
                eventsJson.append(",")
            }
            eventsJson.append(eventJson)
            lastEventId = event.id!
            eventCount += 1
        }
        if eventCount == events.count {
            eventsJson.append("]")
        }
        return BatchEvent(eventsJson: eventsJson, eventCount: eventCount, lastEventId: lastEventId)
    }

    func startBackgroundTask() -> UIBackgroundTaskIdentifier {
        var taskId: UIBackgroundTaskIdentifier?
        #if canImport(UIKit)
            taskId = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
            log.debug("Start background task")
        #endif
        return taskId!
    }

    func endBackgroundTask(taskId: UIBackgroundTaskIdentifier) {
        #if canImport(UIKit)
            UIApplication.shared.endBackgroundTask(taskId)
            log.debug("Ended background task")
        #endif
    }

    func logEventPrettier(event: ClickstreamEvent) {
        log.debug("Event saved, event name: \(event.eventType)")
        print("attributes: {")
        for (key, value) in event.attributes {
            print("  \"\(key)\": \(value)")
        }
        print("}")
    }
}

extension EventRecorder: ClickstreamLogger {}
extension EventRecorder {
    enum Constants {
        static let dbPathPrefix = "com/amazonaws/solution/Clickstream"

        static let maxConcurrentOperations = 1
        static let maxEventOperations = 1_000
        static let maxEventNumberOfBatch = 100
        static let maxSubmissionsAllowed = 3
        static let maxSubmissionSize = 512 * 1_024
        static let maxDbSize = 50 * 1_024 * 1_024
    }
}
