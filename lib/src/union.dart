import 'channel.dart';
import 'error_reporting.dart';
import 'properties.dart';
import 'stack_parser.dart';
import 'types.dart';
import 'version.dart';

/// Union analytics and crash reporting, a thin wrapper over the native Union SDKs.
///
/// Every call is forwarded to the native SDK, which owns sessions, the queue, retries, privacy modes
/// and crash files. Calls are fire-and-forget, never throw into app code, and do nothing before
/// [configure] (the native side ignores them).
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Union.configure(writeKey: 'av_...', privacyMode: PrivacyMode.productAnalytics);
///   runApp(const MyApp());
/// }
/// ```
abstract final class Union {
  /// Configures the native SDK and installs the Dart error handlers.
  ///
  /// Declares the wrapper (`flutter/<plugin version>`) to the native SDK first, then configures it.
  /// Call once, as early as possible, after `WidgetsFlutterBinding.ensureInitialized()`.
  ///
  /// Unless `options.crashReporting` is `false`, installs `FlutterError.onError` and
  /// `PlatformDispatcher.instance.onError` handlers that report uncaught Dart errors as non-fatal
  /// errors with the parsed Dart stack, chaining any handler set before. If the app sets its own
  /// handlers afterwards, call through to the previous ones.
  static Future<void> configure({
    required String writeKey,
    required PrivacyMode privacyMode,
    UnionOptions? options,
  }) async {
    // Captured before the first await, so the caller (the app's `main`) is still on the stack. Its
    // package is the app's root package, used for in_app on Dart frames.
    final callSite = StackTrace.current;
    final opts = options ?? const UnionOptions();

    await invokeUnion<void>('configure', <String, Object?>{
      'writeKey': writeKey,
      'privacyMode': privacyMode.wire,
      'wrapperName': unionWrapperName,
      'wrapperVersion': unionPluginVersion,
      'options': <String, Object?>{
        'environment': opts.environment?.wire,
        'logLevel': opts.logLevel?.wire,
        'crashReporting': opts.crashReporting,
        'hangDetection': opts.hangDetection,
        'inAppPackages': opts.inAppPackages,
      },
    });

    if (opts.crashReporting) {
      try {
        DartErrorReporter.install(
          rule: InAppRule(
            rootPackage: inferRootPackage(callSite),
            inAppPackages: opts.inAppPackages.toSet(),
          ),
        );
      } catch (e) {
        unionDebugLog('could not install error handlers: $e');
      }
    }
  }

  /// Custom event. `name` is lowercase snake_case (`workout_started`); `$`-prefixed names are
  /// reserved. Property values are `String`, finite `num` or `bool`; invalid ones are dropped with a
  /// debug log and the native SDK validates the rest. [feature] + [role] declare the event's place in
  /// a feature (see [Union.feature] for the typed form); [screen] says where it happened.
  static void track(
    String name, {
    Map<String, Object> properties = const <String, Object>{},
    String? feature,
    FeatureRole? role,
    String? screen,
  }) {
    sendUnion('track', <String, Object?>{
      'name': name,
      'properties': sanitizeProperties(properties, context: 'track($name)'),
      'feature': feature,
      'role': role?.wire,
      'screen': screen,
    });
  }

  /// Manual `$screen_view`. With [feature], the view is that feature's discovery step.
  /// [UnionNavigatorObserver] calls this for named routes.
  static void screen(
    String name, {
    Map<String, Object> properties = const <String, Object>{},
    String? feature,
  }) {
    sendUnion('screen', <String, Object?>{
      'name': name,
      'properties': sanitizeProperties(properties, context: 'screen($name)'),
      'feature': feature,
    });
  }

  /// A typed handle for one feature. Define each key once and reuse it: a typo creates a second feature.
  static UnionFeature feature(String key) => UnionFeature._(key);

  /// Attach your own stable, opaque user id after sign-in. Traits (`name`, `email`, `plan`; up to 8,
  /// values up to 256 characters) are merged key by key across calls. Ignored in `strictAnonymous`.
  static void identify(String userId, {Map<String, String> traits = const <String, String>{}}) {
    sendUnion('identify', <String, Object?>{
      'userId': userId,
      'traits': sanitizeTraits(traits),
    });
  }

  /// Sign-out: forgets the user id and starts a new session. The install id is kept.
  static void reset() => sendUnion('reset');

  /// Enables or disables product analytics at runtime while crash and hang reporting stay active.
  static void setAnalyticsCollectionEnabled(bool enabled) =>
      sendUnion('setAnalyticsCollectionEnabled', <String, Object?>{'enabled': enabled});

  /// Stops all Union collection, diagnostics included, and wipes locally stored data. Persists across
  /// launches until [optIn].
  static void optOut() => sendUnion('optOut');

  /// Resumes collection after [optOut].
  static void optIn() => sendUnion('optIn');

  /// Records `$deep_link { url_scheme, host, path }`. The query string and fragment are never sent
  /// (this wrapper strips them before the native call, as the native SDKs do).
  static void handleDeepLink(Uri uri) {
    // Scheme, host and path only: the query and fragment never leave Dart.
    final safe = Uri(scheme: uri.scheme, host: uri.host.isEmpty ? null : uri.host, path: uri.path);
    sendUnion('handleDeepLink', <String, Object?>{'url': safe.toString()});
  }

  /// A caught error that matters, for example `Union.recordError('PaymentFailed', reason: 'card_declined')`.
  static void recordError(String type, {String? reason}) =>
      sendUnion('recordError', <String, Object?>{'type': type, 'reason': reason});

  /// A key/value attached to the next crash report. `null` removes the key.
  static void setCrashKey(String key, String? value) =>
      sendUnion('setCrashKey', <String, Object?>{'key': key, 'value': value});

  /// A breadcrumb attached to the next crash report.
  static void leaveBreadcrumb(String name) =>
      sendUnion('leaveBreadcrumb', <String, Object?>{'name': name});

  /// Uploads queued events now. Completes when the native SDK is done; never throws.
  static Future<void> flush() => invokeUnion<void>('flush');

  /// The pseudonymous install id, or `null` before [configure] and in `strictAnonymous`.
  ///
  /// Pass it to purchases (`PurchaseParam(applicationUserName: await Union.installId)`) or set it as
  /// the RevenueCat attribute `union_install_id` so Union can join revenue to installs.
  static Future<String?> get installId => invokeUnion<String>('getInstallId');
}

/// A handle for one feature: a funnel built from events the code declares.
///
/// One event name is one (feature, role) pair everywhere in the code.
final class UnionFeature {
  const UnionFeature._(this.key);

  final String key;

  /// `$screen_view` for this feature, the usual discovery step. Same as `Union.screen(name, feature: key)`.
  void screen(String name, {Map<String, Object> properties = const <String, Object>{}}) =>
      Union.screen(name, properties: properties, feature: key);

  /// Saw that the feature exists, has not tried it yet. Additive: the setup prompt uses [screen].
  void discovery(String name, {Map<String, Object> properties = const <String, Object>{}}) =>
      _track(name, properties, FeatureRole.discovery);

  /// An attempt whose outcome is not known yet. The funnel's denominator.
  void start(String name, {Map<String, Object> properties = const <String, Object>{}}) =>
      _track(name, properties, FeatureRole.start);

  /// Working inside the feature; may happen many times per attempt. Not a funnel step.
  void use(String name, {Map<String, Object> properties = const <String, Object>{}}) =>
      _track(name, properties, FeatureRole.use);

  /// The feature gave the user what they came for. Once per attempt.
  void success(String name, {Map<String, Object> properties = const <String, Object>{}}) =>
      _track(name, properties, FeatureRole.success);

  /// The attempt failed from the user's point of view.
  void failure(String name, {Map<String, Object> properties = const <String, Object>{}}) =>
      _track(name, properties, FeatureRole.failure);

  void _track(String name, Map<String, Object> properties, FeatureRole role) =>
      Union.track(name, properties: properties, feature: key, role: role);

  @override
  bool operator ==(Object other) => other is UnionFeature && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'UnionFeature($key)';
}
