import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:union_analytics/union_analytics.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChannelRecorder rec;
  setUp(() => rec = ChannelRecorder());
  tearDown(() => rec.dispose());

  List<String> screens() => [for (final c in rec.named('screen')) (c.arguments as Map)['name'] as String];

  Route<void> page(String? name) =>
      MaterialPageRoute<void>(settings: RouteSettings(name: name), builder: (_) => const SizedBox());

  test('push sends the route name', () async {
    UnionNavigatorObserver().didPush(page('/checkout'), page('/'));
    await settle();
    expect(screens(), ['/checkout']);
  });

  test('pop sends the page that reappears', () async {
    UnionNavigatorObserver().didPop(page('/checkout'), page('/'));
    await settle();
    expect(screens(), ['/']);
  });

  test('replace sends the new route', () async {
    UnionNavigatorObserver().didReplace(newRoute: page('/b'), oldRoute: page('/a'));
    await settle();
    expect(screens(), ['/b']);
  });

  test('unnamed routes are skipped on push, pop and replace', () async {
    final o = UnionNavigatorObserver();
    o.didPush(page(null), page('/'));
    o.didPush(page(''), page('/'));
    o.didPop(page('/x'), page(null));
    o.didPop(page('/x'), null);
    o.didReplace(newRoute: page(null), oldRoute: page('/a'));
    o.didReplace(newRoute: null, oldRoute: page('/a'));
    await settle();
    expect(screens(), isEmpty);
  });

  test('dialogs and sheets are not screens, and closing one does not re-report the page', () async {
    final o = UnionNavigatorObserver();
    final dialog = _PopupStub(const RouteSettings(name: '/dialog'));
    o.didPush(dialog, page('/'));
    o.didPop(dialog, page('/'));
    await settle();
    expect(screens(), isEmpty);
  });

  testWidgets('in a real Navigator: initial route, push, pop, pushReplacement', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [UnionNavigatorObserver()],
        routes: {
          '/': (_) => const Scaffold(body: Text('home')),
          '/a': (_) => const Scaffold(body: Text('a')),
          '/b': (_) => const Scaffold(body: Text('b')),
        },
      ),
    );
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushNamed('/a');
    await tester.pumpAndSettle();
    nav.pushReplacementNamed('/b');
    await tester.pumpAndSettle();
    nav.pop();
    await tester.pumpAndSettle();
    expect(screens(), ['/', '/a', '/b', '/']);
  });
}

class _PopupStub extends PopupRoute<void> {
  _PopupStub(RouteSettings settings) : super(settings: settings);

  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => Duration.zero;
  @override
  Widget buildPage(BuildContext context, Animation<double> a, Animation<double> b) => const SizedBox();
}
