/// One parsed frame of a Dart stack, in the shape the native `ManagedFrame` takes.
class UnionStackFrame {
  const UnionStackFrame({
    required this.function,
    this.module,
    this.file,
    this.line,
    this.column,
    required this.inApp,
  });

  /// `Class.method`, `main`, `<anonymous closure>` ... as the VM prints it.
  final String function;

  /// The Dart package name (`flutter`, `my_app`) or `dart:` library (`dart:async`).
  final String? module;

  /// `package:flutter/src/widgets/framework.dart`, `dart:async/zone.dart`, or for `file:` frames the
  /// path from `lib/` (or `test/`, `bin/`) on, else the file name. Absolute paths never leave the device.
  final String? file;
  final int? line;
  final int? column;
  final bool inApp;

  Map<String, Object?> toMap() => <String, Object?>{
        'function': function,
        'module': module,
        'file': file,
        'line': line,
        'column': column,
        'inApp': inApp,
      };

  @override
  bool operator ==(Object other) =>
      other is UnionStackFrame &&
      other.function == function &&
      other.module == module &&
      other.file == file &&
      other.line == line &&
      other.column == column &&
      other.inApp == inApp;

  @override
  int get hashCode => Object.hash(function, module, file, line, column, inApp);

  @override
  String toString() => 'UnionStackFrame($function, $module, $file:$line:$column, inApp: $inApp)';
}

/// Which frames count as the app's own code (`in_app: true`).
///
/// The rule, in order:
///  1. `dart:` and any other scheme except `package:` / `file:` -> not in app.
///  2. `package:<name>/...` -> in app when `<name>` is the app's root package or in `inAppPackages`.
///     When the root package is unknown, no `package:` frame is in app.
///  3. `file:` (debug / JIT / `flutter test` builds print file URIs for app code) -> in app, unless the
///     path is inside the pub cache or the Flutter SDK (`.pub-cache`, `/bin/cache/`, `/packages/flutter`).
///  4. Frames with no URI (unsymbolized, `--split-debug-info`) -> not in app.
class InAppRule {
  const InAppRule({this.rootPackage, this.inAppPackages = const <String>{}});

  final String? rootPackage;
  final Set<String> inAppPackages;

  bool isInApp(String? uriString) {
    if (uriString == null) return false;
    final uri = Uri.tryParse(uriString);
    if (uri == null) return false;
    switch (uri.scheme) {
      case 'package':
        final name = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
        if (name == null) return false;
        return name == rootPackage || inAppPackages.contains(name);
      case 'file':
        final path = uri.path;
        return !(path.contains('/.pub-cache/') ||
            path.contains('/bin/cache/') ||
            path.contains('/flutter/packages/'));
      default:
        return false;
    }
  }
}

/// Maximum frames sent per error; the rest is dropped, innermost first.
const int maxStackFrames = 128;

// `#0      Foo.bar (package:app/main.dart:10:5)` — the VM format, also `flutter test`.
final RegExp _vmFrame = RegExp(r'^#(\d+)\s+(.*?)\s+\((.*)\)\s*$');
// `#0      main` — a frame with no location.
final RegExp _vmBare = RegExp(r'^#(\d+)\s+(\S.*?)\s*$');
// AOT with --split-debug-info: `#00 abs 000000750ed1c5f3 virtual 00000000001b45f3 _kDartIsolateSnapshotInstructions+0x1`
final RegExp _vmAbs = RegExp(r'^#(\d+)\s+abs\s+([0-9a-fA-F]+)(?:\s+virtual\s+[0-9a-fA-F]+)?(?:\s+(.*))?$');
// package:stack_trace friendly format: `package:app/main.dart 10:5  main`.
final RegExp _friendly = RegExp(r'^(\S+?)(?:\s+(\d+):(\d+)|\s+(\d+))?\s{2,}(\S.*?)\s*$');
final RegExp _location = RegExp(r'^(.*?)(?::(\d+))?(?::(\d+))?$');

/// Parses a Dart [StackTrace] into frames, innermost first.
///
/// Understands the VM format (JIT and AOT, with `<asynchronous suspension>` and async gap lines
/// skipped), the `package:stack_trace` friendly format, and AOT `abs` addresses from builds with
/// `--split-debug-info`. Lines it does not understand are skipped; it never throws.
List<UnionStackFrame> parseDartStackTrace(StackTrace? stack, {InAppRule rule = const InAppRule()}) {
  if (stack == null) return const <UnionStackFrame>[];
  final frames = <UnionStackFrame>[];
  try {
    for (final raw in stack.toString().split('\n')) {
      if (frames.length >= maxStackFrames) break;
      final line = raw.trim();
      if (line.isEmpty) continue;
      final frame = _parseLine(line, rule);
      if (frame != null) frames.add(frame);
    }
  } catch (_) {
    // A parser bug must not lose the report; send what was parsed.
  }
  return frames;
}

UnionStackFrame? _parseLine(String line, InAppRule rule) {
  // Async gaps: `<asynchronous suspension>`, `===== asynchronous gap ===========`.
  if (line.startsWith('<asynchronous') || line.startsWith('=====')) return null;

  final abs = _vmAbs.firstMatch(line);
  if (abs != null) {
    final rest = abs.group(3);
    return UnionStackFrame(
      function: (rest == null || rest.isEmpty) ? 'abs 0x${abs.group(2)}' : rest,
      inApp: false,
    );
  }

  final vm = _vmFrame.firstMatch(line);
  if (vm != null) {
    return _frame(function: vm.group(2)!, location: vm.group(3)!, rule: rule);
  }
  if (line.startsWith('#')) {
    final bare = _vmBare.firstMatch(line);
    if (bare == null) return null;
    return UnionStackFrame(function: bare.group(2)!, inApp: false);
  }

  final friendly = _friendly.firstMatch(line);
  if (friendly != null && RegExp(r'^(package|dart|file|https?):').hasMatch(friendly.group(1)!)) {
    final uri = friendly.group(1)!;
    final ln = friendly.group(2) ?? friendly.group(4);
    final loc = ln == null ? uri : '$uri:$ln${friendly.group(3) == null ? '' : ':${friendly.group(3)}'}';
    return _frame(function: friendly.group(5)!, location: loc, rule: rule);
  }
  return null;
}

UnionStackFrame _frame({required String function, required String location, required InAppRule rule}) {
  final m = _location.firstMatch(location)!;
  final uri = m.group(1)!;
  // `dart:core` has no `:line`; `_location` leaves line/column null then.
  final scheme = Uri.tryParse(uri)?.scheme;
  return UnionStackFrame(
    function: function,
    module: _module(uri, scheme),
    file: _file(uri, scheme),
    line: m.group(2) == null ? null : int.tryParse(m.group(2)!),
    column: m.group(3) == null ? null : int.tryParse(m.group(3)!),
    inApp: rule.isInApp(uri),
  );
}

String? _module(String uri, String? scheme) {
  switch (scheme) {
    case 'package':
      final u = Uri.tryParse(uri);
      return (u == null || u.pathSegments.isEmpty) ? null : u.pathSegments.first;
    case 'dart':
      final end = uri.indexOf('/');
      return end < 0 ? uri : uri.substring(0, end);
    default:
      return null;
  }
}

String? _file(String uri, String? scheme) {
  if (scheme != 'file') return uri.isEmpty ? null : uri;
  final path = Uri.tryParse(uri)?.path ?? uri;
  for (final marker in const ['/lib/', '/test/', '/bin/']) {
    final i = path.lastIndexOf(marker);
    if (i >= 0) return path.substring(i + 1);
  }
  final slash = path.lastIndexOf('/');
  return slash < 0 ? path : path.substring(slash + 1);
}

/// The app's root package, read from the call site of `Union.configure`: the first `package:` frame
/// that is neither this plugin nor Flutter itself. `null` when the stack has no such frame (for
/// example `flutter test`, which prints `file:` URIs).
String? inferRootPackage(StackTrace stack) {
  for (final raw in stack.toString().split('\n')) {
    final frame = _parseLine(raw.trim(), const InAppRule());
    final module = frame?.module;
    if (frame == null || module == null || frame.file == null) continue;
    if (!frame.file!.startsWith('package:')) continue;
    if (module == 'union_analytics' || module == 'flutter') continue;
    return module;
  }
  return null;
}
