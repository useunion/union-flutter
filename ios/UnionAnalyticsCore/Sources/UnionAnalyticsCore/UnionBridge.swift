import Foundation
@_spi(Wrapper) import Union

public enum UnionBridgeResult {
    case success(Any?)
    case notImplemented
}

/// Forwards one method-channel call to the native Union SDK. Wrapper rule: nothing here queues,
/// retries, owns a session or talks to ingest; every call is the native SDK's.
public final class UnionBridge {
    public init() {}

    /// Handles `method`. `completion` is called exactly once, possibly on a background thread.
    public func handle(method: String, arguments: Any?, completion: @escaping (UnionBridgeResult) -> Void) {
        let args = arguments as? [String: Any] ?? [:]
        switch method {
        case "configure":
            // setWrapper must come before configure: the device context is built once per client.
            if let name = Arguments.string(args, "wrapperName"), let version = Arguments.string(args, "wrapperVersion") {
                Union.setWrapper(name: name, version: version)
            }
            if let key = Arguments.string(args, "writeKey"), let mode = Arguments.privacyMode(Arguments.string(args, "privacyMode")) {
                Union.configure(writeKey: key, privacyMode: mode, options: Arguments.options(args["options"]))
            }
            completion(.success(nil))

        case "track":
            if let name = Arguments.string(args, "name") {
                Union.track(
                    name,
                    properties: Arguments.properties(args["properties"]),
                    feature: Arguments.string(args, "feature"),
                    role: Arguments.featureRole(Arguments.string(args, "role")),
                    screen: Arguments.string(args, "screen")
                )
            }
            completion(.success(nil))

        case "screen":
            if let name = Arguments.string(args, "name") {
                Union.screen(name, properties: Arguments.properties(args["properties"]), feature: Arguments.string(args, "feature"))
            }
            completion(.success(nil))

        case "identify":
            if let id = Arguments.string(args, "userId") {
                Union.identify(userId: id, traits: Arguments.traits(args["traits"]))
            }
            completion(.success(nil))

        case "reset":
            Union.reset()
            completion(.success(nil))

        case "setAnalyticsCollectionEnabled":
            if let enabled = Arguments.bool(args, "enabled") { Union.setAnalyticsCollectionEnabled(enabled) }
            completion(.success(nil))

        case "optOut":
            Union.optOut()
            completion(.success(nil))

        case "optIn":
            Union.optIn()
            completion(.success(nil))

        case "handleDeepLink":
            if let url = Arguments.url(args) { Union.handleDeepLink(url) }
            completion(.success(nil))

        case "recordError":
            if let type = Arguments.string(args, "type") {
                Union.recordError(type, reason: Arguments.string(args, "reason"))
            }
            completion(.success(nil))

        case "setCrashKey":
            if let key = Arguments.string(args, "key") { Union.setCrashKey(key, Arguments.string(args, "value")) }
            completion(.success(nil))

        case "leaveBreadcrumb":
            if let name = Arguments.string(args, "name") { Union.leaveBreadcrumb(name) }
            completion(.success(nil))

        case "recordManagedError":
            if let type = Arguments.string(args, "type") {
                Union.recordManagedError(
                    type: type,
                    reason: Arguments.string(args, "reason"),
                    frames: Arguments.frames(args["frames"]),
                    fatal: Arguments.bool(args, "fatal") ?? false,
                    thread: Arguments.string(args, "thread") ?? "main"
                )
            }
            completion(.success(nil))

        case "flush":
            Task {
                await Union.flush()
                completion(.success(nil))
            }

        case "getInstallId":
            completion(.success(Union.installId))

        default:
            completion(.notImplemented)
        }
    }
}
