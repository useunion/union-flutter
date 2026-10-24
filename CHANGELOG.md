# Changelog

## 0.1.0

- First release. Dart API over the native Union iOS (0.4.0) and Android (0.1.0) SDKs:
  `Union.configure`, `track`, `screen`, `feature`, `identify`, `reset`, `setAnalyticsCollectionEnabled`,
  `optOut`, `optIn`, `handleDeepLink`, `recordError`, `setCrashKey`, `leaveBreadcrumb`, `flush`, `installId`.
- `UnionNavigatorObserver` for named routes.
- Uncaught Dart errors (`FlutterError.onError`, `PlatformDispatcher.onError`) reported as non-fatal
  managed errors with the parsed Dart stack. Previous handlers are chained.
- `device.sdk_wrapper = "flutter/0.1.0"` via the native wrapper bridge.
- Not supported yet: symbolication of `--obfuscate` / `--split-debug-info` Dart stacks.
