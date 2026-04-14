//
//  Attachment.swift
//  CoreBarcelona
//
//  Created by Eric Rabil on 9/11/20.
//  Copyright © 2020 Eric Rabil. All rights reserved.
//

import BarcelonaDB
import CoreGraphics
import Foundation
import IMCore
import Logging

public struct Size: Codable, Hashable {
    public var width: Float
    public var height: Float

    public init(cgSize: CGSize) {
        width = abs(Float(cgSize.width))
        height = abs(Float(cgSize.height))
    }

    public init(width: CGFloat, height: CGFloat) {
        self.width = abs(Float(width))
        self.height = abs(Float(height))
    }
}

extension IMFileTransfer {
    @_transparent private var compatibilityGUIDKey: String {
        "__kIMFileTransferCompatibilityGUIDKey"
    }

    /// A non-nil GUID which will more than likely be true to the underlying transfer.
    public var assertedGUID: String {
        if let guid = guid {
            return guid
        } else {
            Logger(label: "IMFileTransfer")
                .error(
                    "Encountered an IMFileTransfer with no GUID. Returning a fake GUID for compatibility.",
                    source: "IMFileTransfer+Barcelona"
                )
            return compatibilityGUIDKey
        }
    }
}

public struct Attachment: Codable, Hashable {
    public init(
        mime: String? = nil,
        filename: String,
        id: String,
        uti: String? = nil,
        origin: ResourceOrigin? = nil,
        size: Size? = nil,
        sticker: StickerInformation? = nil
    ) {
        self.mime = mime
        self.filename = filename
        self.id = id
        self.uti = uti
        self.origin = origin
        self.size = size
        self.sticker = sticker
    }

    public init(_ transfer: IMFileTransfer) {
        transfer.ensureLocalPath()

        mime = transfer.mimeType
        filename = transfer.filename
        id = transfer.assertedGUID
        uti = transfer.type
        size = transfer.mediaSize
        path = transfer.localPath

        if transfer.isSticker {
            sticker = StickerInformation(transfer.stickerUserInfo)
        } else {
            sticker = nil
        }
    }

    public init?(guid: String) {
        // `transferForGUID:includeRemoved:` is a private IMSharedUtilities selector that
        // existed on macOS 13–15 but was removed in macOS 26. Paris still declares it in
        // its IMFileTransferCenter headers, so the Swift compiler accepts the call, but
        // invoking it on macOS 26 raises NSInvalidArgumentException
        // ("unrecognized selector sent to instance ...") and aborts the daemon mid-sync
        // (e.g. when GetGroupChatAvatarCommand fetches a chat avatar). Guard with
        // respondsToSelector and fall back to the single-arg `transferForGUID:` variant,
        // which is widely used elsewhere in this codebase and remains available on
        // macOS 26. (`includeRemoved: false` matches the default behavior of the
        // single-arg method, so the fallback is semantically equivalent.)
        let center = IMFileTransferCenter.sharedInstance()
        let twoArgSel = NSSelectorFromString("transferForGUID:includeRemoved:")

        let item: IMFileTransfer?
        if (center as AnyObject).responds(to: twoArgSel) {
            item = center.transfer(forGUID: guid, includeRemoved: false)
        } else {
            item = center.transfer(forGUID: guid)
        }

        guard let item, item.ensuredLocalPath != nil else {
            return nil
        }

        self.init(item)
    }

    public var mime: String?
    public var filename: String
    public var id: String
    public var originalGUID: String?
    public var uti: String?
    public var origin: ResourceOrigin?
    public var size: Size?
    public var sticker: StickerInformation?

    public var name: String {
        filename
    }

    public var existingFileTransfer: IMFileTransfer? {
        BLLoadFileTransfer(withGUID: id)
    }

    public var path: String?

    public var url: URL? {
        path.map(URL.init(fileURLWithPath:))
    }

    @discardableResult
    public func initializeFileTransferIfNeeded() async -> IMFileTransfer? {
        if let transfer = existingFileTransfer {
            return transfer
        } else if let url = url {
            return await CBInitializeFileTransfer(filename: filename, path: url)
        } else {
            return nil
        }
    }
}
