import Foundation

#if !canImport(Union)
#error("The Union iOS SDK is not available. union_analytics needs Swift Package Manager on iOS (Flutter >= 3.24, `flutter config --enable-swift-package-manager`); the Union iOS SDK has no CocoaPods spec. See the README.")
#endif
@_spi(Wrapper) import Union

/// Maps method-channel arguments (what Flutter's standard codec decodes) to native Union types.
/// Pure functions; invalid input yields `nil` or is dropped, never a crash.
enum Arguments {
    static func string(_ args: [String: Any], _ key: String) -> String? {
        args[key] as? String
    }

    static func bool(_ args: [String: Any], _ key: String) -> Bool? {
        guard let n = args[key] as? NSNumber, isBool(n) else { return nil }
        return n.boolValue
    }

    /// The standard codec decodes Dart `bool` and `int`/`double` all into `NSNumber`; a bool must not
    /// be read as `1`.
    static func isBool(_ n: NSNumber) -> Bool {
        CFGetTypeID(n) == CFBooleanGetTypeID()
    }

    /// `String`, `bool`, finite number. Anything else is dropped; the native SDK validates the rest.
    static func properties(_ raw: Any?) -> [String: PropertyValue] {
        guard let dict = raw as? [String: Any] else { return [:] }
        var out: [String: PropertyValue] = [:]
        for (key, value) in dict {
            if let s = value as? String {
                out[key] = .string(s)
            } else if let n = value as? NSNumber {
                if isBool(n) {
                    out[key] = .bool(n.boolValue)
                } else if n.doubleValue.isFinite {
                    out[key] = .number(n.doubleValue)
                }
            }
        }
        return out
    }

    static func traits(_ raw: Any?) -> [String: String] {
        guard let dict = raw as? [String: Any] else { return [:] }
        return dict.compactMapValues { $0 as? String }
    }

    static func privacyMode(_ raw: String?) -> PrivacyMode? {
        raw.flatMap(PrivacyMode.init(rawValue:))
    }

    static func featureRole(_ raw: String?) -> FeatureRole? {
        raw.flatMap(FeatureRole.init(rawValue:))
    }

    static func logLevel(_ raw: String?) -> LogLevel? {
        switch raw {
        case "debug": return .debug
        case "info": return .info
        case "warning": return .warning
        case "error": return .error
        case "none": return .none
        default: return nil
        }
    }

    static func options(_ raw: Any?) -> Options {
        var options = Options()
        guard let dict = raw as? [String: Any] else { return options }
        if let env = (dict["environment"] as? String).flatMap(Environment.init(rawValue:)) {
            options.environment = env
        }
        if let level = logLevel(dict["logLevel"] as? String) { options.logLevel = level }
        if let b = bool(dict, "crashReporting") { options.crashReporting = b }
        if let b = bool(dict, "hangDetection") { options.hangDetection = b }
        // Screens come from the Dart observer; native UIKit swizzling would only see the one FlutterViewController.
        options.automaticScreenTracking = false
        return options
    }

    static func int(_ value: Any?) -> Int? {
        guard let n = value as? NSNumber, !isBool(n) else { return nil }
        return n.intValue
    }

    static func frames(_ raw: Any?) -> [ManagedFrame] {
        guard let list = raw as? [Any] else { return [] }
        return list.compactMap { item in
            guard let f = item as? [String: Any], let function = f["function"] as? String else { return nil }
            return ManagedFrame(
                function: function,
                module: f["module"] as? String,
                file: f["file"] as? String,
                line: int(f["line"]),
                column: int(f["column"]),
                inApp: (f["inApp"] as? NSNumber)?.boolValue ?? false
            )
        }
    }

    /// Scheme, host and path only, as the Dart side already sends it.
    static func url(_ args: [String: Any]) -> URL? {
        string(args, "url").flatMap(URL.init(string:))
    }
}
