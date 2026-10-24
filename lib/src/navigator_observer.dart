import 'package:flutter/widgets.dart';

import 'union.dart';

/// Sends `Union.screen(route.settings.name)` when a page becomes visible: on push, on pop (the page
/// underneath reappears) and on replace.
///
/// **Named routes only.** A route without `RouteSettings.name` is skipped, so give routes stable
/// names (`MaterialApp.routes`, `onGenerateRoute`, `GoRoute(name: ...)`). Only page routes count:
/// dialogs, bottom sheets and popups are not screens, and closing one does not re-report the page
/// under it.
class UnionNavigatorObserver extends NavigatorObserver {
  UnionNavigatorObserver();

  void _screen(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    Union.screen(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _screen(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Closing a dialog is not navigation; closing a page reveals the one below.
    if (route is PageRoute) _screen(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _screen(newRoute);
}
