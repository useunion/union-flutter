import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:flutter/foundation.dart';

import 'channel.dart';
import 'stack_parser.dart';

/// Reports uncaught Dart errors to the native SDK as non-fatal managed errors.
///
/// Installs `FlutterError.onError` and `PlatformDispatcher.instance.onError`, chaining whatever was
/// set before: the previous `FlutterError.onError` is always called, and the previous
/// `PlatformDispatcher.onError` decides the return value (when there was none, `false`, so the
/// engine's default handling still runs). Errors are `nonfatal` on purpose: a Dart error that
/// reaches these handlers did not end the process.
class DartErrorReporter {
  DartErrorReporter._();

  static FlutterExceptionHandler? _flutterHandler;
  static ErrorCallback? _dispatcherHandler;
  static InAppRule _rule = const InAppRule();

  /// Maximum length of `reason`; a `FlutterError` can carry a multi-page diagnostics dump.
  static const int maxReasonLength = 1024;

  static void install({required InAppRule rule}) {
    _rule = rule;

    final previousFlutter = FlutterError.onError;
    if (!identical(previousFlutter, _flutterHandler)) {
      void handler(FlutterErrorDetails details) {
        report(details.exception, details.stack);
        if (previousFlutter != null) {
          previousFlutter(details);
        } else {
          FlutterError.presentError(details);
        }
      }

      _flutterHandler = handler;
      FlutterError.onError = handler;
    }

    final previousDispatcher = PlatformDispatcher.instance.onError;
    if (!identical(previousDispatcher, _dispatcherHandler)) {
      bool handler(Object error, StackTrace stack) {
        report(error, stack);
        return previousDispatcher?.call(error, stack) ?? false;
      }

      _dispatcherHandler = handler;
      PlatformDispatcher.instance.onError = handler;
    }
  }

  /// Sends one error. Never throws.
  static void report(Object error, StackTrace? stack) {
    try {
      var reason = error.toString();
      if (reason.length > maxReasonLength) reason = reason.substring(0, maxReasonLength);
      final frames = parseDartStackTrace(stack, rule: _rule);
      sendUnion('recordManagedError', <String, Object?>{
        'type': error.runtimeType.toString(),
        'reason': reason,
        'frames': [for (final f in frames) f.toMap()],
        'fatal': false,
        'thread': 'main',
      });
    } catch (e) {
      unionDebugLog('could not report error: $e');
    }
  }
}
