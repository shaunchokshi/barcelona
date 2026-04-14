//
//  ChatOperations+Handler.swift
//  BarcelonaMautrixIPC
//
//  Created by Eric Rabil on 8/23/21.
//  Copyright © 2021 Eric Rabil. All rights reserved.
//

import Barcelona
import BarcelonaDB
import Foundation
import IMCore
import Logging
import Sentry

extension Array where Element == String {
    /// Given self is an array of chat GUIDs, masks the GUIDs to iMessage service and returns the deduplicated result
    func dedupeChatGUIDs() -> [String] {
        Array(Set(self))
    }
}

extension GetChatsCommand: Runnable {
    func run(payload: IPCPayload, ipcChannel: MautrixIPCChannel) async {
        let span = SentrySDK.startIPCTransaction(forPayload: payload, uppercasedName: "GetChatsCommand")

        // `min_timestamp <= 0` → return every chat currently known to IMChatRegistry.
        // Pure Swift against `IMChatRegistry.shared.allChats` + `blChatIdentifier`; no
        // IMD XPC calls, no direct chat.db access. Safe on macOS 26 — the same
        // enumeration runs during CBDaemonListener setup (see `loadedChats:N` log line).
        // Each chat carries its own `groupID` as `thread_id`, matching what `get_chat`
        // returns later when the bridge syncs each portal individually.
        if min_timestamp <= 0 {
            payload.reply(
                withResponse: .chats_resolved(IMChatRegistry.shared.allChats.map(\.blChatIdentifier)),
                ipcChannel: ipcChannel
            )
            span.finish()
            return
        }

        // `min_timestamp > 0` → return every chat that has a message newer than the
        // supplied timestamp. Reads chat.db via GRDB (SQLite) directly. Does NOT use
        // `IMDSetIsRunningInDatabaseServerProcess(1)` — that hack was removed in the
        // macOS 26 compatibility patch because it crashes IMDPersistence.framework.
        // GRDB opens chat.db with full-disk-access credentials and runs a read-only
        // SELECT against chat_message_join ⋈ chat; no private-framework calls in the
        // hot path. See BarcelonaDB/Queries/ChatMessageJoins.swift.
        //
        // chat.db doesn't expose `groupID` via the timestamp query — `thread_id` is
        // left nil and the bridge will populate it via a follow-up `get_chat` call
        // for each portal it decides to backfill. The Go-side `imessage.ChatIdentifier`
        // struct declares `thread_id` with `omitempty`, so nil is wire-compatible.
        do {
            let timestamps = try await DBReader.shared.latestMessageTimestamps()

            let guids = timestamps
                .mapValues { timestamp, guid in
                    (IMDPersistenceTimestampToUnixSeconds(timestamp: timestamp), guid)
                }
                .filter { _, pair in pair.0 > min_timestamp }
                .map(\.value.1)

            let identifiers = guids.dedupeChatGUIDs().map { ChatIdentifier(chat_guid: $0) }

            payload.reply(withResponse: .chats_resolved(identifiers), ipcChannel: ipcChannel)
            span.finish()
        } catch {
            payload.fail(strategy: .internal_error(error.localizedDescription), ipcChannel: ipcChannel)
            SentrySDK.capture(error: error)
            span.finish(status: .internalError)
        }
    }
}

extension GetGroupChatInfoCommand: Runnable {
    var log: Logging.Logger {
        Logger(label: "TapbackCommand")
    }
    func run(payload: IPCPayload, ipcChannel: MautrixIPCChannel) async {
        let span = SentrySDK.startIPCTransaction(forPayload: payload, uppercasedName: "GetGroupChatInfoCommand")

        log.info("Getting chat with id \(chat_guid)", source: "MautrixIPC")

        guard let chat = await blChat else {
            payload.fail(strategy: .chat_not_found, ipcChannel: ipcChannel)
            span.finish(status: .notFound)
            return
        }
        SentrySDK.configureScope { scope in
            scope.setContext(
                value: [
                    "guid": chat_guid,
                    "service": chat.service,
                ],
                key: "blchat"
            )
        }

        payload.respond(.chat_resolved(chat), ipcChannel: ipcChannel)
        span.finish()
    }
}

extension SendReadReceiptCommand: Runnable, AuthenticatedAsserting {
    var log: Logging.Logger {
        Logger(label: "TapbackCommand")
    }
    func run(payload: IPCPayload, ipcChannel: MautrixIPCChannel) async {
        let span = SentrySDK.startIPCTransaction(forPayload: payload, uppercasedName: "SendReadReceiptCommand")

        let chatGUID = await cbChat?.blChatGUID
        log.info("Sending read receipt to \(String(describing: chatGUID))", source: "MautrixIPC")

        guard let chat = await cbChat else {
            payload.fail(strategy: .chat_not_found, ipcChannel: ipcChannel)
            span.finish(status: .notFound)
            return
        }
        SentrySDK.configureScope { scope in
            scope.setContext(
                value: [
                    "id": chat.id,
                    "service": String(describing: chat.service),
                ],
                key: "chat"
            )
        }

        chat.markMessageAsRead(withID: read_up_to)
        span.finish()
    }
}

extension SendTypingCommand: Runnable, AuthenticatedAsserting {
    func run(payload: IPCPayload, ipcChannel: MautrixIPCChannel) async {
        let span = SentrySDK.startIPCTransaction(forPayload: payload, uppercasedName: "SendTypingCommand")

        guard let chat = await cbChat else {
            payload.fail(strategy: .chat_not_found, ipcChannel: ipcChannel)
            span.finish(status: .notFound)
            return
        }
        SentrySDK.configureScope { scope in
            scope.setContext(
                value: [
                    "id": chat.id,
                    "service": String(describing: chat.service),
                ],
                key: "chat"
            )
        }

        chat.setTyping(typing)
        span.finish()
    }
}

extension GetGroupChatAvatarCommand: Runnable {
    func run(payload: IPCPayload, ipcChannel: MautrixIPCChannel) async {
        let span = SentrySDK.startIPCTransaction(forPayload: payload, uppercasedName: "GetGroupChatAvatarCommand")

        guard let chat = await chat, let groupPhotoID = chat.groupPhotoID else {
            payload.respond(.chat_avatar(nil), ipcChannel: ipcChannel)
            span.finish()
            return
        }
        SentrySDK.configureScope { scope in
            scope.setContext(
                value: [
                    "id": chat.id
                ],
                key: "imchat"
            )
        }

        payload.respond(.chat_avatar(BLAttachment(guid: groupPhotoID)), ipcChannel: ipcChannel)
        span.finish()
    }
}
