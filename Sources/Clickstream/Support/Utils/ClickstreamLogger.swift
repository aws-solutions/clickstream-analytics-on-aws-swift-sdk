//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify

public protocol ClickstreamLogger {
    static var log: Logger { get }
    var log: Logger { get }
}

public extension ClickstreamLogger {
    static var log: Logger {
        Amplify.Logging.logger(forCategory: String(describing: self), logLevel: LogLevel.debug)
    }

    func setLogLevel(logLevel: LogLevel) {
        _ = Amplify.Logging.logger(forCategory: String(describing: self), logLevel: logLevel)
    }

    var log: Logger {
        type(of: self).log
    }
}
