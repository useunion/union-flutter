import 'channel.dart';

/// Light validation of event properties on the Dart side.
///
/// Values must be `String`, finite `num` or `bool`. Anything else is dropped with a debug log, and
/// the rest is sent. The native SDK stays the authority (name rules, 256-character strings, count
/// limits); this only keeps values the platform codecs cannot represent faithfully away from it.
Map<String, Object> sanitizeProperties(Map<String, Object>? properties, {String context = 'event'}) {
  if (properties == null || properties.isEmpty) return const <String, Object>{};
  final out = <String, Object>{};
  properties.forEach((key, value) {
    if (value is String || value is bool) {
      out[key] = value;
    } else if (value is num) {
      if (value.isFinite) {
        out[key] = value;
      } else {
        unionDebugLog('$context: property "$key" dropped, number is not finite');
      }
    } else {
      unionDebugLog('$context: property "$key" dropped, ${value.runtimeType} is not String, num or bool');
    }
  });
  return out;
}

/// Traits are `String -> String` by type; this guards against `Map<String, dynamic>` casts at runtime.
Map<String, String> sanitizeTraits(Map<String, String>? traits) {
  if (traits == null || traits.isEmpty) return const <String, String>{};
  final out = <String, String>{};
  traits.forEach((key, value) {
    // ignore: unnecessary_type_check
    if ((value as Object?) is String) {
      out[key] = value;
    } else {
      unionDebugLog('identify: trait "$key" dropped, value is not a String');
    }
  });
  return out;
}
