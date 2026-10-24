import 'package:flutter_test/flutter_test.dart';
import 'package:union_analytics/src/stack_parser.dart';

/// A [StackTrace] with fixed text, as the VM would print it.
class _Trace implements StackTrace {
  _Trace(this.text);
  final String text;
  @override
  String toString() => text;
}

const _rule = InAppRule(rootPackage: 'my_app', inAppPackages: {'my_feature'});

void main() {
  group('VM format', () {
    test('package frames, closures, constructors and dart: frames', () {
      final frames = parseDartStackTrace(
        _Trace('''
#0      _CheckoutState._pay.<anonymous closure> (package:my_app/checkout/checkout_page.dart:57:11)
#1      new Order (package:my_app/models/order.dart:12:3)
#2      State.setState (package:flutter/src/widgets/framework.dart:1189:9)
#3      _rootRunUnary (dart:async/zone.dart:1407:47)
#4      _CustomZone.runUnary (dart:async/zone.dart:1308:19)
#5      main (package:my_app/main.dart:9:3)
#6      PaymentService.charge (package:my_feature/src/payment.dart:30:7)
'''),
        rule: _rule,
      );
      expect(frames.length, 7);
      expect(
        frames[0],
        const UnionStackFrame(
          function: '_CheckoutState._pay.<anonymous closure>',
          module: 'my_app',
          file: 'package:my_app/checkout/checkout_page.dart',
          line: 57,
          column: 11,
          inApp: true,
        ),
      );
      expect(frames[1].function, 'new Order');
      expect(frames[1].inApp, isTrue);
      expect(frames[2].module, 'flutter');
      expect(frames[2].inApp, isFalse);
      expect(frames[3], const UnionStackFrame(function: '_rootRunUnary', module: 'dart:async', file: 'dart:async/zone.dart', line: 1407, column: 47, inApp: false));
      expect(frames[5].inApp, isTrue);
      expect(frames[6].module, 'my_feature');
      expect(frames[6].inApp, isTrue, reason: 'inAppPackages');
    });

    test('async suspension and async gap lines are skipped', () {
      final frames = parseDartStackTrace(
        _Trace('''
#0      CheckoutController.submit (package:my_app/checkout/controller.dart:44:5)
<asynchronous suspension>
#1      _CheckoutState._pay (package:my_app/checkout/checkout_page.dart:60:7)
<asynchronous suspension>
===== asynchronous gap ===========================
#2      Api.post (package:my_app/api.dart:8:1)
'''),
        rule: _rule,
      );
      expect(frames.map((f) => f.function), ['CheckoutController.submit', '_CheckoutState._pay', 'Api.post']);
      expect(frames.map((f) => f.line), [44, 60, 8]);
    });

    test('file: frames from debug builds are in app, trimmed to lib/', () {
      final frames = parseDartStackTrace(
        _Trace('''
#0      main (file:///Users/jane/dev/my_app/lib/main.dart:14:3)
#1      _runMain.<anonymous closure> (file:///Users/jane/dev/my_app/test/widget_test.dart:5:1)
#2      helper (file:///Users/jane/dev/my_app/tool.dart:2:2)
#3      Dep.run (file:///Users/jane/.pub-cache/hosted/pub.dev/dep-1.0.0/lib/dep.dart:3:3)
#4      Widget.build (file:///opt/homebrew/share/flutter/packages/flutter/lib/src/widgets/basic.dart:1:1)
'''),
        rule: const InAppRule(rootPackage: 'my_app'),
      );
      expect(frames[0].file, 'lib/main.dart');
      expect(frames[0].inApp, isTrue);
      expect(frames[0].module, isNull);
      expect(frames[1].file, 'test/widget_test.dart');
      expect(frames[2].file, 'tool.dart');
      expect(frames[2].inApp, isTrue);
      expect(frames[3].inApp, isFalse, reason: 'pub cache');
      expect(frames[4].inApp, isFalse, reason: 'flutter sdk');
      for (final f in frames) {
        expect(f.file, isNot(contains('Users')));
      }
    });

    test('frame without a line or column and a frame without a location', () {
      final frames = parseDartStackTrace(
        _Trace('''
#0      Foo.bar (package:my_app/foo.dart:7)
#1      Zone.run (dart:core)
#2      <fn>
'''),
        rule: _rule,
      );
      expect(frames[0].line, 7);
      expect(frames[0].column, isNull);
      expect(frames[1].file, 'dart:core');
      expect(frames[1].line, isNull);
      expect(frames[2], const UnionStackFrame(function: '<fn>', inApp: false));
    });

    test('AOT frames from --split-debug-info keep their address, never in app', () {
      final frames = parseDartStackTrace(
        _Trace('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
pid: 1234, tid: 5678, name 1.ui
build_id: 'a1b2c3'
isolate_dso_base: 7a00000000, vm_dso_base: 7a00000000
#00 abs 0000007a0c3c1f2b virtual 00000000004c1f2b _kDartIsolateSnapshotInstructions+0x1234
#01 abs 0000007a0c3c2000
'''),
        rule: _rule,
      );
      expect(frames.length, 2);
      expect(frames[0].function, '_kDartIsolateSnapshotInstructions+0x1234');
      expect(frames[1].function, 'abs 0x0000007a0c3c2000');
      expect(frames.every((f) => !f.inApp), isTrue);
    });

    test('the exception header and other prose lines are not frames', () {
      final frames = parseDartStackTrace(
        _Trace('''
Bad state: no element
#0      List.first (dart:core-patch/growable_array.dart:343:5)
#1      main (package:my_app/main.dart:3:3)
'''),
        rule: _rule,
      );
      expect(frames.length, 2);
      expect(frames[0].module, 'dart:core-patch');
    });
  });

  group('package:stack_trace friendly format', () {
    test('uri line:col  member', () {
      final frames = parseDartStackTrace(
        _Trace('''
package:my_app/main.dart 10:5                    main
package:flutter/src/widgets/framework.dart 1189:9  State.setState
dart:async/zone.dart 1407:47                      _rootRunUnary
===== asynchronous gap ===========================
package:my_app/api.dart 8:1                       Api.post
'''),
        rule: _rule,
      );
      expect(frames.map((f) => f.function), ['main', 'State.setState', '_rootRunUnary', 'Api.post']);
      expect(frames[0], const UnionStackFrame(function: 'main', module: 'my_app', file: 'package:my_app/main.dart', line: 10, column: 5, inApp: true));
      expect(frames[1].inApp, isFalse);
      expect(frames[2].module, 'dart:async');
    });
  });

  group('limits and safety', () {
    test('null and empty traces give no frames', () {
      expect(parseDartStackTrace(null), isEmpty);
      expect(parseDartStackTrace(StackTrace.empty), isEmpty);
    });

    test('at most $maxStackFrames frames', () {
      final text = [for (var i = 0; i < 300; i++) '#$i      f$i (package:my_app/a.dart:$i:1)'].join('\n');
      final frames = parseDartStackTrace(_Trace(text), rule: _rule);
      expect(frames.length, maxStackFrames);
      expect(frames.first.function, 'f0');
    });

    test('unknown root package means no package: frame is in app', () {
      final frames = parseDartStackTrace(
        _Trace('#0      main (package:my_app/main.dart:1:1)'),
      );
      expect(frames.single.inApp, isFalse);
    });

    test('a real StackTrace.current parses without throwing', () {
      final frames = parseDartStackTrace(StackTrace.current, rule: const InAppRule(rootPackage: 'union_analytics'));
      expect(frames, isNotEmpty);
    });
  });

  group('inferRootPackage', () {
    test('first package: frame that is not this plugin or flutter', () {
      final pkg = inferRootPackage(_Trace('''
#0      Union.configure (package:union_analytics/src/union.dart:40:5)
#1      main (package:my_app/main.dart:8:9)
#2      _runMain (dart:ui/hooks.dart:300:23)
'''));
      expect(pkg, 'my_app');
    });

    test('skips flutter frames', () {
      expect(
        inferRootPackage(_Trace('''
#0      Union.configure (package:union_analytics/src/union.dart:40:5)
#1      Binding.run (package:flutter/src/x.dart:1:1)
#2      main (package:shop/main.dart:8:9)
''')),
        'shop',
      );
    });

    test('null when the stack only has file: frames (flutter test)', () {
      expect(
        inferRootPackage(_Trace('''
#0      Union.configure (file:///x/union-flutter/lib/src/union.dart:40:5)
#1      main (file:///x/union-flutter/test/union_test.dart:8:9)
''')),
        isNull,
      );
    });
  });
}
