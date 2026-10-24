/// Mirrors `privacy_mode` in the wire contract. Must match the project's setting in Union
/// (Settings -> Privacy); it cannot be changed later.
enum PrivacyMode {
  /// Never persists an install id or user id.
  strictAnonymous('strict_anonymous'),

  /// Pseudonymous install id, `identify`, retention and funnels.
  productAnalytics('product_analytics');

  const PrivacyMode(this.wire);

  /// The value on the method channel and in the wire contract.
  final String wire;
}

/// The event's role inside a feature. See the feature plan section of the Union setup prompt.
enum FeatureRole {
  discovery,
  start,
  use,
  success,
  failure;

  /// The value on the method channel.
  String get wire => name;
}

/// Mirrors `environment` in the wire contract.
enum UnionEnvironment {
  development,
  testflight,
  production;

  String get wire => name;
}

/// Verbosity of the native SDK's own logging (Logcat tag `Union`, Xcode console).
enum UnionLogLevel {
  debug,
  info,
  warning,
  error,
  none;

  String get wire => name;
}

/// Options for [Union.configure].
///
/// Only the options a Flutter app needs. `automaticScreenTracking` is deliberately not exposed:
/// screens come from [UnionNavigatorObserver] (or [Union.screen]), and the native automatic tracking
/// would report the single `FlutterViewController` / `FlutterActivity` instead of Dart routes.
class UnionOptions {
  const UnionOptions({
    this.environment,
    this.logLevel,
    this.crashReporting = true,
    this.hangDetection = true,
    this.inAppPackages = const <String>[],
  });

  /// Overrides the native environment detection (debug build -> `development`).
  /// On Android a pre-release store build that should read as `testflight` must set this.
  final UnionEnvironment? environment;

  /// Native SDK log level. `null` keeps the native default (`warning`).
  final UnionLogLevel? logLevel;

  /// Native crash reporting and uncaught Dart error reporting. On by default. `false` installs
  /// nothing on either side, including the Dart error handlers.
  final bool crashReporting;

  /// Native hang (iOS, Android) and ANR (Android) detection.
  final bool hangDetection;

  /// Additive to the documented API. Dart packages whose frames count as the app's own code
  /// (`in_app: true`) in Dart stacks, in addition to the app's root package. Needed for monorepos
  /// where app code lives in local packages.
  final List<String> inAppPackages;
}
