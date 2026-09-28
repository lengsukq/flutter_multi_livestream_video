@_implementationOnly import AmazonIVSChatMessaging
import Flutter
import Foundation

public final class FlutterRealtimeChatIvsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private static let methodChannelName = "com.oneplusdream.flutter_realtime_chat_ivs/methods"
    private static let eventChannelName = "com.oneplusdream.flutter_realtime_chat_ivs/events"

    private var methodChannel: FlutterMethodChannel?
    private var eventSink: FlutterEventSink?
    private var room: ChatRoom?
    private var initialToken: ChatToken?
    private var connectedOnce = false
    private var clientDisconnecting = false
    private lazy var roomDelegate = IvsChatRoomDelegate(owner: self)

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterRealtimeChatIvsPlugin()
        let messenger = registrar.messenger()
        let methods = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: messenger
        )
        let events = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: messenger
        )
        instance.methodChannel = methods
        methods.setMethodCallHandler(instance.handle)
        events.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            connect(call.arguments, result: result)
        case "sendMessage":
            guard let message = string(call.arguments, key: "message") else {
                result(FlutterError(code: "invalid_argument", message: "message is required.", details: nil))
                return
            }
            sendMessage(message, result: result)
        case "deleteMessage":
            guard let messageId = string(call.arguments, key: "messageId") else {
                result(FlutterError(code: "invalid_argument", message: "messageId is required.", details: nil))
                return
            }
            deleteMessage(messageId, result: result)
        case "disconnectUser":
            guard let userId = string(call.arguments, key: "userId") else {
                result(FlutterError(code: "invalid_argument", message: "userId is required.", details: nil))
                return
            }
            disconnectUser(userId, result: result)
        case "disconnect":
            disconnect()
            result(nil)
        case "dispose":
            disposeRoom()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func connect(_ arguments: Any?, result: @escaping FlutterResult) {
        guard room == nil else {
            result(FlutterError(code: "invalid_state", message: "An Amazon IVS Chat room is already active.", details: nil))
            return
        }
        guard
            let region = string(arguments, key: "region"),
            let token = token(from: arguments)
        else {
            result(FlutterError(code: "invalid_argument", message: "Valid IVS Chat credentials are required.", details: nil))
            return
        }

        initialToken = token
        connectedOnce = false
        clientDisconnecting = false

        let chatRoom = ChatRoom(
            awsRegion: region,
            asyncTokenProvider: { [weak self] in
                guard let self else {
                    throw BridgeError("IVS Chat Flutter bridge was disposed.")
                }
                if let token = self.initialToken {
                    self.initialToken = nil
                    return token
                }
                return try await self.requestFreshToken()
            }
        )
        chatRoom.delegate = roomDelegate
        room = chatRoom
        chatRoom.connect { _, error in
            DispatchQueue.main.async {
                if let error {
                    result(
                        FlutterError(
                            code: "native_error",
                            message: error.localizedDescription,
                            details: String(describing: error)
                        )
                    )
                } else {
                    result(nil)
                }
            }
        }
    }

    private func requestFreshToken() async throws -> ChatToken {
        guard let methodChannel else {
            throw BridgeError("IVS Chat Flutter method channel is unavailable.")
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                methodChannel.invokeMethod("requestToken", arguments: nil) { response in
                    if let error = response as? FlutterError {
                        continuation.resume(
                            throwing: BridgeError(error.message ?? "Unable to refresh IVS Chat token.")
                        )
                        return
                    }
                    guard let token = self.token(from: response) else {
                        continuation.resume(
                            throwing: BridgeError("Flutter returned invalid IVS Chat credentials.")
                        )
                        return
                    }
                    continuation.resume(returning: token)
                }
            }
        }
    }

    private func sendMessage(_ message: String, result: @escaping FlutterResult) {
        guard let room else {
            result(FlutterError(code: "invalid_state", message: "No active Amazon IVS Chat room.", details: nil))
            return
        }
        room.sendMessage(
            with: SendMessageRequest(content: message),
            onSuccess: { _ in DispatchQueue.main.async { result(nil) } },
            onFailure: { error in DispatchQueue.main.async { result(self.flutterError(error)) } }
        )
    }

    private func deleteMessage(_ messageId: String, result: @escaping FlutterResult) {
        guard let room else {
            result(FlutterError(code: "invalid_state", message: "No active Amazon IVS Chat room.", details: nil))
            return
        }
        room.deleteMessage(
            with: DeleteMessageRequest(id: messageId),
            onSuccess: { _ in DispatchQueue.main.async { result(nil) } },
            onFailure: { error in DispatchQueue.main.async { result(self.flutterError(error)) } }
        )
    }

    private func disconnectUser(_ userId: String, result: @escaping FlutterResult) {
        guard let room else {
            result(FlutterError(code: "invalid_state", message: "No active Amazon IVS Chat room.", details: nil))
            return
        }
        room.disconnectUser(
            with: DisconnectUserRequest(id: userId),
            onSuccess: { _ in DispatchQueue.main.async { result(nil) } },
            onFailure: { error in DispatchQueue.main.async { result(self.flutterError(error)) } }
        )
    }

    private func disconnect() {
        clientDisconnecting = true
        room?.disconnect()
        initialToken = nil
    }

    private func disposeRoom() {
        clientDisconnecting = true
        room?.disconnect()
        room?.delegate = nil
        room = nil
        initialToken = nil
        connectedOnce = false
    }

    private func flutterError(_ error: ChatError) -> FlutterError {
        let rawCode = error.errorCode.rawValue
        let code: String
        switch rawCode {
        case 401:
            code = "unauthorized"
        case 403:
            code = "forbidden"
        default:
            code = "native_error"
        }
        return FlutterError(
            code: code,
            message: error.errorMessage ?? "Amazon IVS Chat request failed.",
            details: [
                "errorCode": rawCode,
                "id": error.id,
                "requestId": error.requestId as Any,
            ]
        )
    }

    private func token(from arguments: Any?) -> ChatToken? {
        guard
            let map = arguments as? [String: Any],
            let token = map["token"] as? String,
            !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let tokenExpirationMs = int64(map["tokenExpirationTimeMs"]),
            let sessionExpirationMs = int64(map["sessionExpirationTimeMs"])
        else {
            return nil
        }
        return ChatToken(
            token: token,
            tokenExpirationTime: Date(timeIntervalSince1970: Double(tokenExpirationMs) / 1000.0),
            sessionExpirationTime: Date(timeIntervalSince1970: Double(sessionExpirationMs) / 1000.0)
        )
    }

    private func string(_ arguments: Any?, key: String) -> String? {
        guard let map = arguments as? [String: Any] else { return nil }
        let value = String(describing: map[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func int64(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber { return number.int64Value }
        if let text = value as? String { return Int64(text) }
        return nil
    }

    fileprivate func emit(_ event: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }

    fileprivate func roomIsConnecting() {
        emit([
            "type": "connecting",
            "reconnecting": connectedOnce,
        ])
    }

    fileprivate func roomDidConnect() {
        connectedOnce = true
        clientDisconnecting = false
        emit(["type": "connected"])
    }

    fileprivate func roomDidDisconnect() {
        emit([
            "type": "disconnected",
            "reason": clientDisconnecting ? "clientDisconnect" : "unknown",
        ])
    }

    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

private final class IvsChatRoomDelegate: NSObject, ChatRoomDelegate {
    private weak var owner: FlutterRealtimeChatIvsPlugin?

    init(owner: FlutterRealtimeChatIvsPlugin) {
        self.owner = owner
    }

    func roomIsConnecting(_ room: ChatRoom) {
        owner?.roomIsConnecting()
    }

    func roomDidConnect(_ room: ChatRoom) {
        owner?.roomDidConnect()
    }

    func roomDidDisconnect(_ room: ChatRoom) {
        owner?.roomDidDisconnect()
    }

    func room(_ room: ChatRoom, didReceive message: ChatMessage) {
        var attributes = message.attributes ?? [:]
        for (key, value) in message.sender.attributes ?? [:]
        where attributes[key] == nil {
            attributes[key] = value
        }
        owner?.emit([
            "type": "message",
            "id": message.id,
            "userId": message.sender.userId,
            "displayName": attributes["displayName"] ?? message.sender.userId,
            "message": message.content,
            "timestampMs":
                Int64(message.sendTime.timeIntervalSince1970 * 1000.0),
            "attributes": attributes,
        ])
    }

    func room(_ room: ChatRoom, didDelete message: DeletedMessage) {
        owner?.emit([
            "type": "messageDeleted",
            "messageId": message.messageID,
        ])
    }

    func room(_ room: ChatRoom, didDisconnect user: DisconnectedUser) {
        owner?.emit([
            "type": "userDisconnected",
            "userId": user.userId,
        ])
    }
}

private struct BridgeError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
