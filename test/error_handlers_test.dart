import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:union_analytics/union_analytics.dart';

import 'helpers.dart';

class CheckoutException implements Exception {
  @override
  String toString() => 'CheckoutException: card declined';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChannelRecorder rec;
  late FlutterExceptionHandler? originalFlutter;
  late ErrorCallback? originalDispatcher;

  setUp(() {
    rec = ChannelRecorder();
    originalFlutter = FlutterError.onError;
    originalDispatcher = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = originalFlutter;
    PlatformDispatcher.instance.onError = originalDispatcher;
    rec.dispose();
  });

  Future<void> configure({UnionOptions? options}) =>
      Union.configure(writeKey: 'k', privacyMode: PrivacyMode.productAnalytics, options: options);

  List<dynamic> managedErrors() => rec.named('recordManagedError');

  test('FlutterError.onError reports a non-fatal managed error and chains the previous handler', () async {
    final seen = <FlutterErrorDetails>[];
    FlutterError.onError = seen.add;
    await configure();

    final stack = StackTrace.fromString('''
#0      Foo.bar (package:my_app/foo.dart:7:3)
<asynchronous suspension>
#1      main (package:my_app/main.dart:3:3)
''');
    final details = FlutterErrorDetails(exception: CheckoutException(), stack: stack);
    FlutterError.onError!(details);
    await settle();

    expect(seen, [details], reason: 'the previous handler still runs');
    final call = managedErrors().single as dynamic;
    final args = call.arguments as Map;
    expect(args['type'], 'CheckoutException');
    expect(args['reason'], 'CheckoutException: card declined');
    expect(args['fatal'], false);
    expect(args['thread'], 'main');
    final frames = args['frames'] as List;
    expect(frames.length, 2);
    expect((frames[0] as Map)['function'], 'Foo.bar');
    expect((frames[0] as Map)['line'], 7);
    expect((frames[0] as Map)['file'], 'package:my_app/foo.dart');
  });

  test('PlatformDispatcher.onError reports and returns the previous handler\'s verdict', () async {
    final seen = <Object>[];
    PlatformDispatcher.instance.onError = (error, stack) {
      seen.add(error);
      return true;
    };
    await configure();

    final handled = PlatformDispatcher.instance.onError!(StateError('boom'), StackTrace.current);
    await settle();

    expect(handled, isTrue);
    expect(seen.single, isA<StateError>());
    final args = (managedErrors().single as dynamic).arguments as Map;
    expect(args['type'], 'StateError');
    expect(args['reason'], 'Bad state: boom');
    expect(args['fatal'], false);
    expect((args['frames'] as List), isNotEmpty);
  });

  test('without a previous PlatformDispatcher handler it returns false, so default handling runs', () async {
    PlatformDispatcher.instance.onError = null;
    await configure();
    final handled = PlatformDispatcher.instance.onError!(ArgumentError('x'), StackTrace.current);
    expect(handled, isFalse);
  });

  test('previous handlers that return false are respected', () async {
    PlatformDispatcher.instance.onError = (e, s) => false;
    await configure();
    expect(PlatformDispatcher.instance.onError!(Exception('x'), StackTrace.current), isFalse);
  });

  test('calling configure twice does not chain our handler onto itself', () async {
    final seen = <FlutterErrorDetails>[];
    FlutterError.onError = seen.add;
    await configure();
    final first = FlutterError.onError;
    await configure();
    expect(identical(FlutterError.onError, first), isTrue);

    FlutterError.onError!(FlutterErrorDetails(exception: Exception('once')));
    await settle();
    expect(managedErrors().length, 1, reason: 'one report, not one per configure');
    expect(seen.length, 1);
  });

  test('crashReporting: false installs no Dart handlers', () async {
    final before = FlutterError.onError;
    final beforeDispatcher = PlatformDispatcher.instance.onError;
    await configure(options: const UnionOptions(crashReporting: false));
    expect(identical(FlutterError.onError, before), isTrue);
    expect(identical(PlatformDispatcher.instance.onError, beforeDispatcher), isTrue);
  });

  test('a throwing channel does not break the handler chain', () async {
    final seen = <FlutterErrorDetails>[];
    FlutterError.onError = seen.add;
    await configure();
    rec.dispose(); // no native side: invokeMethod throws MissingPluginException
    FlutterError.onError!(FlutterErrorDetails(exception: Exception('x')));
    await settle();
    expect(seen.length, 1);
  });

  test('a very long reason is cut', () async {
    FlutterError.onError = (_) {};
    await configure();
    FlutterError.onError!(FlutterErrorDetails(exception: 'x' * 5000));
    await settle();
    final args = (managedErrors().single as dynamic).arguments as Map;
    expect((args['reason'] as String).length, 1024);
    expect(args['type'], 'String');
  });

  test('an error without a stack still reports, with no frames', () async {
    FlutterError.onError = (_) {};
    await configure();
    FlutterError.onError!(FlutterErrorDetails(exception: Exception('no stack')));
    await settle();
    final args = (managedErrors().single as dynamic).arguments as Map;
    expect(args['frames'], isEmpty);
  });

  test('in_app uses the app root package and options.inAppPackages', () async {
    // Under `flutter test` the configure call site has file: frames, so the root package is unknown and
    // only inAppPackages count for package: frames.
    FlutterError.onError = (_) {};
    await configure(options: const UnionOptions(inAppPackages: ['my_feature']));
    FlutterError.onError!(FlutterErrorDetails(
      exception: Exception('x'),
      stack: StackTrace.fromString('''
#0      A.a (package:my_feature/a.dart:1:1)
#1      B.b (package:somepkg/b.dart:1:1)
#2      C.c (file:///home/dev/app/lib/c.dart:1:1)
'''),
    ));
    await settle();
    final frames = ((managedErrors().single as dynamic).arguments as Map)['frames'] as List;
    expect([for (final f in frames) (f as Map)['inApp']], [true, false, true]);
  });
}
