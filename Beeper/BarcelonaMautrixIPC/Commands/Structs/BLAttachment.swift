//
//  BLAttachment.swift
//  BarcelonaMautrixIPC
//
//  Created by Eric Rabil on 5/24/21.
//  Copyright © 2021 Eric Rabil. All rights reserved.
//

import Barcelona
import Foundation

public struct BLAttachment: Codable {
    public var mime_type: String?
    public var file_name: String
    public var path_on_disk: String

    public init?(guid: String) {
        // Bail when the underlying transfer has no usable on-disk path. The
        // existing `let path = attachment.path` guard only catches `nil`, but
        // `IMFileTransfer.localPath` can also return an empty string when the
        // file is referenced by GUID but hasn't been materialised locally
        // (common for iCloud-only group chat avatars whose photo data hasn't
        // been downloaded). Forwarding an empty path produces a wire payload
        // with `path_on_disk: ""`, which mautrix-imessage's Go side then
        // tries to `os.Open("")` and logs as:
        //
        //     ERR Failed to read avatar attachment: open : no such file or
        //         directory portal_guid=any;+;chat...
        //
        // The Go side already handles `chat_avatar: null` cleanly — failing
        // the init returns nil here, the caller wraps it in `.chat_avatar(nil)`
        // (BLAttachment? case), and the bridge silently skips the avatar.
        guard let attachment = Attachment(guid: guid),
              let path = attachment.path,
              !path.isEmpty
        else {
            return nil
        }

        mime_type = attachment.mime
        file_name = attachment.name
        path_on_disk = path
    }
}
