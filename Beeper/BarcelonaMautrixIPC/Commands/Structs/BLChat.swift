//
//  BLChat.swift
//  BarcelonaMautrixIPC
//
//  Created by Eric Rabil on 5/24/21.
//  Copyright © 2021 Eric Rabil. All rights reserved.
//

import Barcelona
import Foundation
import IMCore

extension IMChat {
    public var blChat: BLChat {
        BLChat(
            chat_guid: blChatGUID,
            title: displayName,
            members: participants.map(\.id),
            thread_id: groupID
        )
    }

    /// Minimal `{chat_guid, thread_id?}` representation of the chat. Used as the
    /// element type of the `get_chats` IPC response — mautrix-imessage's Go side
    /// declares the response body as `[]imessage.ChatIdentifier` (see
    /// imessage/struct.go). Returning bare GUID strings produces:
    ///
    ///     ERR Failed to get chat list to backfill error="failed to parse response:
    ///     json: cannot unmarshal string into Go value of type imessage.ChatIdentifier"
    public var blChatIdentifier: ChatIdentifier {
        ChatIdentifier(chat_guid: blChatGUID, thread_id: groupID)
    }
}

public struct BLChat: Codable, ChatResolvable {
    public var chat_guid: String
    public var title: String?
    public var members: [String]?
    // This is the stable-ish chat UUID, called thread_id because mautrix-imessage already has that field
    public var thread_id: String?
}

/// Wire-compatible mirror of mautrix-imessage's Go-side `imessage.ChatIdentifier`:
///
///     type ChatIdentifier struct {
///         ChatGUID string `json:"chat_guid"`
///         ThreadID string `json:"thread_id,omitempty"`
///     }
///
/// Used as the element type of `IPCResponse.chats_resolved`, which carries the
/// reply payload for the `get_chats` IPC command.
public struct ChatIdentifier: Codable {
    public var chat_guid: String
    public var thread_id: String?

    public init(chat_guid: String, thread_id: String? = nil) {
        self.chat_guid = chat_guid
        self.thread_id = thread_id
    }
}
