//
//  IMChat+ForceRefresh.swift
//  Barcelona
//
//  Created by Eric Rabil on 8/2/22.
//

import Foundation
import IMCore
import Logging

// Lazily-initialised, thread-safe "log once per process" helpers for the
// private-selector availability checks in `watchAllHandles()` below.
// `static let` initializers in Swift are guaranteed to run exactly once
// (dispatch_once under the hood), so assigning the Logger call to
// `static let` means the message is emitted the first time the property
// is touched and never again. Without this, the daemon logs one line
// per IMChat at startup (~200+ lines for a typical user's chat history).
private enum WatchAllHandlesAvailabilityLog {
    static let beginObservingHandleAvailabilityMissing: Void = {
        Logger(label: "IMChat")
            .debug(
                "IMChat does not respond to beginObservingHandleAvailability on this macOS version; skipping for all chats (further occurrences suppressed)",
                source: "IMChat"
            )
    }()

    static let startWatchingIMHandleMissing: Void = {
        Logger(label: "IMChat")
            .debug(
                "IMAccount does not respond to startWatchingIMHandle: on this macOS version; skipping for all chats (further occurrences suppressed)",
                source: "IMChat"
            )
    }()
}

extension IMChat {
    public var log: Logging.Logger {
        Logger(label: "IMChat")
    }

    /// Returns true if the next message sent will be sent over SMS
    public var willSendSMS: Bool {
        account.service?.id == .SMS
    }

    /// Returns true if there are data inconsistencies warranting a service refresh
    public var forceRefresh: Bool {
        if isSingle && willSendSMS && recipient?.id.isEmail == true {
            return true
        }
        return false
    }

    // Call to ensure that all handles are being watched so that we don't miss any mesages from them
    @available(macOS 13.0, *)
    public func watchAllHandles() {
        // `beginObservingHandleAvailability` is a private IMCore selector that exists on
        // macOS 13–15 but was removed in macOS 26. Paris still declares it in its IMCore
        // headers, so the Swift compiler accepts the call, but invoking it on macOS 26
        // raises NSInvalidArgumentException ("unrecognized selector sent to instance ...")
        // and aborts the daemon. Guard with respondsToSelector before invoking.
        let observeSel = NSSelectorFromString("beginObservingHandleAvailability")
        if (self as AnyObject).responds(to: observeSel) {
            _ = (self as AnyObject).perform(observeSel)
        } else {
            // Log once per process; see WatchAllHandlesAvailabilityLog above.
            _ = WatchAllHandlesAvailabilityLog.beginObservingHandleAvailabilityMissing
        }

        guard let participants else {
            log.warning("Chat \(String(describing: self.guid)) participants is nil, can't watch them", source: "IMChat")
            return
        }

        // Watch all the people who are in the chat. Also guarded with respondsToSelector
        // since `startWatchingIMHandle:` is similarly a private IMAccount selector that
        // could disappear in future SDK revisions.
        let watchSel = NSSelectorFromString("startWatchingIMHandle:")
        if (account as AnyObject).responds(to: watchSel) {
            for handle in participants {
                _ = (account as AnyObject).perform(watchSel, with: handle)
            }
        } else {
            // Log once per process; see WatchAllHandlesAvailabilityLog above.
            _ = WatchAllHandlesAvailabilityLog.startWatchingIMHandleMissing
        }
    }
}
