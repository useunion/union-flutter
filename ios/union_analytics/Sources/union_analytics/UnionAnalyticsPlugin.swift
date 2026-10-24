import Flutter
#if canImport(UnionAnalyticsCore)
import UnionAnalyticsCore
#endif

/// Moves method-channel calls from Dart into the native Union SDK (`UnionBridge`). No logic of its
/// own: the wrapper never queues, retries, owns sessions or talks to ingest.
public final class UnionAnalyticsPlugin: NSObject, FlutterPlugin {
    private let bridge = UnionBridge()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dev.useunion/union", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(UnionAnalyticsPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        bridge.handle(method: call.method, arguments: call.arguments) { outcome in
            // Replies go back on the platform thread; `flush` completes on a background one.
            DispatchQueue.main.async {
                switch outcome {
                case .success(let value): result(value)
                case .notImplemented: result(FlutterMethodNotImplemented)
                }
            }
        }
    }
}
