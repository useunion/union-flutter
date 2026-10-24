import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The one method channel. Every public call is a thin message to the native SDK: the plugin never
/// queues, retries or talks to ingest.
const MethodChannel unionChannel = MethodChannel('dev.useunion/union');

/// Invokes [method] and never throws: a broken or missing native side must not take the app down.
Future<T?> invokeUnion<T>(String method, [Map<String, Object?>? arguments]) async {
  try {
    return await unionChannel.invokeMethod<T>(method, arguments);
  } on MissingPluginException catch (e) {
    unionDebugLog('$method: native side not available ($e)');
  } on PlatformException catch (e) {
    unionDebugLog('$method failed: ${e.code} ${e.message}');
  } catch (e) {
    unionDebugLog('$method failed: $e');
  }
  return null;
}

/// Fire-and-forget form for calls that return nothing.
void sendUnion(String method, [Map<String, Object?>? arguments]) {
  // ignore: discarded_futures
  invokeUnion<void>(method, arguments);
}

/// Debug-only log; silent in release.
void unionDebugLog(String message) {
  if (kDebugMode) debugPrint('[Union] $message');
}
