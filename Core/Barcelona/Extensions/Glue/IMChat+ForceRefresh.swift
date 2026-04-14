//
//  IMChat+ForceRefresh.swift
//  Barcelona
//
//  Created by Eric Rabil on 8/2/22.
//

import Foundation
import IMCore
import Logging

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
            log.debug(
                "IMChat does not respond to beginObservingHandleAvailability on this macOS version; skipping",
                source: "IMChat"
            )
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
            log.debug(
                "IMAccount does not respond to startWatchingIMHandle: on this macOS version; skipping",
                source: "IMChat"
            )
        }
    }
}
