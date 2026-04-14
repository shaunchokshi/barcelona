//
//  IPCResponse.swift
//  BarcelonaMautrixIPC
//
//  Created by Eric Rabil on 6/1/21.
//  Copyright © 2021 Eric Rabil. All rights reserved.
//

import Foundation
import Logging

extension IPCPayload {
    public func respond(_ response: IPCResponse, ipcChannel: MautrixIPCChannel) {
        self.reply(withCommand: .response(response), ipcChannel: ipcChannel)
    }
}

public enum IPCResponse: Encodable {
    // `chats_resolved` is the reply payload for the `get_chats` IPC command.
    // mautrix-imessage's Go side unmarshals this into `[]imessage.ChatIdentifier`,
    // so the array element must serialize to `{"chat_guid": ..., "thread_id": ...}`
    // — NOT a bare string GUID. See ChatIdentifier in BLChat.swift for the
    // wire-compatible mirror of the Go-side struct.
    case chats_resolved([ChatIdentifier])
    case chat_resolved(BLChat?)
    case messages([BLMessage])
    case chat_avatar(BLAttachment?)
    case message_receipt(BLPartialMessage)
    case guid(GUIDResponse)
    case arbitrary(any Codable)
    case ack
    case none

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .chats_resolved(let data):
            try container.encode(data)
        case .chat_resolved(let data):
            try container.encode(data)
        case .messages(let data):
            try container.encode(data)
        case .chat_avatar(let data):
            try container.encode(data)
        case .message_receipt(let data):
            try container.encode(data)
        case .arbitrary(let codable):
            try container.encode(codable)
        case .ack:
            try container.encodeNil()
        case .none:
            try container.encodeNil()
        case .guid(let data):
            try container.encode(data)
        }
    }
}
