//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Network

protocol NetworkMonitor: AnyObject {
    var isOnline: Bool { get }
    var netWorkType: String { get }
    func startMonitoring(using queue: DispatchQueue)
    func stopMonitoring()
}

var currentNetWorkType: String = NetWorkType.UnKnow

extension NWPathMonitor: NetworkMonitor {
    var isOnline: Bool {
        currentPath.status == .satisfied
    }

    var netWorkType: String { currentNetWorkType }

    func startMonitoring(using queue: DispatchQueue) {
        start(queue: queue)
        pathUpdateHandler = { path in
            if path.usesInterfaceType(.wifi) {
                currentNetWorkType = NetWorkType.Wifi
            } else if path.usesInterfaceType(.cellular) {
                currentNetWorkType = NetWorkType.Mobile
            }
        }
    }

    func stopMonitoring() {
        cancel()
    }
}

enum NetWorkType {
    static let Wifi = "WIFI"
    static let UnKnow = "UNKNOWN"
    static let Mobile = "Mobile"
}
