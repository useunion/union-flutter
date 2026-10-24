# union_analytics

Product analytics and crash reporting for Flutter apps, for [Union](https://useunion.dev).

A thin wrapper over the native Union iOS and Android SDKs. The wrapper never talks to ingest, never
queues and never owns sessions: every call is forwarded to the native SDK, and events carry
`sdk_wrapper: "flutter/<version>"`.

## Install

```sh
flutter pub add union_analytics
```

Requirements: Flutter 3.24+, iOS 16+, Android minSdk 24.

**iOS needs Swift Package Manager.** The Union iOS SDK is a Swift package with no CocoaPods spec, so the
plugin is integrated through Flutter's SwiftPM support:

```sh
flutter config --enable-swift-package-manager
```

CocoaPods is not a supported install path for this plugin; the podspec exists only so tooling can resolve
it and fails to compile with an explanatory message if the Union module is missing.

**Android** resolves `dev.useunion:union:0.1.0` from Maven Central. Until it is published, run
`./gradlew :union:publishToMavenLocal` in `union-android` and add `mavenLocal()` to your app's repositories
(the example app does).

Development note: `ios/UnionAnalyticsCore/Package.swift` points at the local `union-ios` checkout. At release it
switches to `https://github.com/useunion/union-ios` from `0.4.0`.

## Configure

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // privacyMode must match the project in Union (Settings -> Privacy); it cannot be changed later.
  await Union.configure(writeKey: 'av_...', privacyMode: PrivacyMode.productAnalytics);
  runApp(const MyApp());
}
```

`UnionOptions` (all optional): `environment`, `logLevel`, `crashReporting` (default on), `hangDetection`
(default on), and `inAppPackages` (see Errors). One key serves every build; the native SDK decides the
environment (debug builds are `development`).

## Screens

```dart
MaterialApp(
  navigatorObservers: [UnionNavigatorObserver()],
  routes: {'/': (_) => const Home(), '/checkout': (_) => const Checkout()},
);
```

With `go_router`:

```dart
GoRouter(
  observers: [UnionNavigatorObserver()],
  routes: [GoRoute(name: 'checkout', path: '/checkout', builder: ...)],
);
```

The observer sends `Union.screen(route.settings.name)` on push, pop (the page underneath) and replace.
**Unnamed routes are skipped**, and only page routes count (dialogs and sheets are not screens). Give routes
stable names. For screens that are not routes (tabs inside one route) call `Union.screen('Name')`.
`automaticScreenTracking` is deliberately not exposed: native tracking would only see the single Flutter view.

## Identify

```dart
Union.identify('<stable, opaque user id>', traits: {'plan': 'pro'}); // after sign-in
Union.reset();                                                      // on sign-out
```

## Events and features

```dart
Union.track('settings_changed', properties: {'setting': 'units'});

final checkout = Union.feature('checkout');
checkout.screen('Checkout');                                           // discovery
checkout.start('checkout_started');                                    // start
checkout.use('shipping_selected');                                     // use
checkout.success('order_placed', properties: {'items': 3});            // success
checkout.failure('payment_failed', properties: {'reason': 'card_declined'}); // failure
```

Event names are lowercase `snake_case`. Property values are `String`, finite `num` or `bool`; the plugin drops
anything else with a debug log and the native SDK does the authoritative validation. One event name is one
(feature, role) pair everywhere.

## Errors

`configure` installs `FlutterError.onError` and `PlatformDispatcher.instance.onError` handlers. Uncaught Dart
errors are reported as **non-fatal** errors with the parsed Dart stack (`exception.type` is the error's
`runtimeType`). Any handler set before is chained; if your app sets its own afterwards, call through to the
previous one. `crashReporting: false` installs nothing, on either side.

A frame is `in_app` when:

- its URI is `package:<name>/...` and `<name>` is the app's root package (read from the call site of
  `Union.configure`) or listed in `UnionOptions.inAppPackages` (needed for monorepos with local packages);
- or it is a `file:` URI (debug and JIT builds) outside the pub cache and the Flutter SDK.

`dart:` frames and frames with no URI are never in app. `file:` paths are cut to start at `lib/`, `test/` or
`bin/`, so absolute paths do not leave the device.

```dart
Union.recordError('PaymentFailed', reason: 'card_declined'); // a caught error that matters
Union.setCrashKey('plan', 'pro');
Union.leaveBreadcrumb('opened_cart');
```

Native crashes on both platforms are reported by the native SDKs.

## Purchases

With `in_app_purchase`, pass the install id as the account identifier on every purchase:

```dart
final id = await Union.installId;
final param = PurchaseParam(productDetails: product, applicationUserName: id);
```

On iOS that becomes the StoreKit `appAccountToken`, on Android the obfuscated account id. Not retroactive.

With RevenueCat:

```dart
final id = await Union.installId;
if (id != null) await Purchases.setAttributes({'union_install_id': id});
```

`installId` is `null` before `configure` and in `strictAnonymous`.

## Privacy

- `PrivacyMode.strictAnonymous` never persists an install id or user id; `identify` is ignored.
- `Union.setAnalyticsCollectionEnabled(false)` stops analytics but keeps crash reporting; `Union.optOut()` stops
  everything and wipes local data until `Union.optIn()`.
- `handleDeepLink(Uri)` sends scheme, host and path only; the query and fragment never leave Dart.
- App Store: Product Interaction, Device ID and User ID, linked to the user, analytics, not tracking. No ATT
  prompt. Google Play Data safety: App activity, Device or other IDs; crash logs as App info and performance.

## Limits

- **No `--obfuscate` support yet.** Union cannot read Flutter symbol files, so stacks from builds with
  `--obfuscate` / `--split-debug-info` arrive as raw addresses. Do not use them unless you accept unreadable
  Dart stacks.
- Uncaught Dart errors are non-fatal; the fatal path of the native bridge is not used by this version.
- Android symbol upload (R8 mapping) is the native Gradle plugin's job.

## Contributing

See `CLAUDE.md`: wrappers forward only, the contract lives in `union-panel/packages/contract`.
