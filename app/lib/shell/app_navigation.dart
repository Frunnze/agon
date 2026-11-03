import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/shell/app_route.dart';

final class AppNavigation extends ChangeNotifier {
  AppNavigation({required AppRoute initialRoute})
    : _routes = List<AppRoute>.unmodifiable(<AppRoute>[initialRoute]);

  List<AppRoute> _routes;

  List<AppRoute> get routes => _routes;

  AppRoute get currentRoute => _routes.last;

  void openRoute(AppRoute route) {
    _routes = List<AppRoute>.unmodifiable(<AppRoute>[..._routes, route]);
    notifyListeners();
  }

  void openSection(AppRoute sectionRoute) {
    _routes = List<AppRoute>.unmodifiable(<AppRoute>[sectionRoute]);
    notifyListeners();
  }

  void replaceRoute(AppRoute route) {
    final List<AppRoute> below = _routes.sublist(0, _routes.length - 1);

    _routes = List<AppRoute>.unmodifiable(<AppRoute>[...below, route]);
    notifyListeners();
  }

  void closeSavedForm() {
    _routes = List<AppRoute>.unmodifiable(_listRoutesBelowSavedForm());
    notifyListeners();
  }

  void replaceSavedForm(AppRoute destination) {
    _routes = List<AppRoute>.unmodifiable(<AppRoute>[
      ..._listRoutesBelowSavedForm(),
      destination,
    ]);
    notifyListeners();
  }

  void closeRoute() {
    if (_routes.length < 2) {
      throw StateError('The first page of a section cannot be closed');
    }

    _routes = List<AppRoute>.unmodifiable(
      _routes.sublist(0, _routes.length - 1),
    );
    notifyListeners();
  }

  List<AppRoute> _listRoutesBelowSavedForm() {
    final List<AppRoute> below = _routes.sublist(0, _routes.length - 1);
    final bool isOfferedByNewPage =
        below.length > 1 && below.last is NewPageRoute;
    if (isOfferedByNewPage) {
      return below.sublist(0, below.length - 1);
    }
    return below;
  }

  void returnTo(AppRoute route) {
    final bool isDirectlyBelow =
        _routes.length > 1 && _routes[_routes.length - 2] == route;

    if (isDirectlyBelow) {
      closeRoute();
    } else {
      replaceRoute(route);
    }
  }
}
