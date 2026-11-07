import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_route.dart';

typedef RouteAdmission = bool Function(AppRoute route);

bool _admitEveryRoute(AppRoute route) {
  return true;
}

bool _admitRunPages(AppRoute route) {
  return route is RunPageRoute;
}

final class AppNavigation extends ChangeNotifier {
  AppNavigation({required AppRoute initialRoute})
    : this._admitting(initialRoute: initialRoute, canOpen: _admitEveryRoute);

  AppNavigation.limitedToRunPages({required RunId runId})
    : this._admitting(
        initialRoute: TaskRunRoute(runId),
        canOpen: _admitRunPages,
      );

  AppNavigation._admitting({
    required AppRoute initialRoute,
    required this.canOpen,
  }) : _routes = List<AppRoute>.unmodifiable(<AppRoute>[initialRoute]);

  final RouteAdmission canOpen;
  List<AppRoute> _routes;

  List<AppRoute> get routes => _routes;

  AppRoute get currentRoute => _routes.last;

  void openRoute(AppRoute route) {
    _requireOpenable(route);
    _routes = List<AppRoute>.unmodifiable(<AppRoute>[..._routes, route]);
    notifyListeners();
  }

  void openSection(AppRoute sectionRoute) {
    _requireOpenable(sectionRoute);
    _routes = List<AppRoute>.unmodifiable(<AppRoute>[sectionRoute]);
    notifyListeners();
  }

  void replaceRoute(AppRoute route) {
    _requireOpenable(route);
    final List<AppRoute> below = _routes.sublist(0, _routes.length - 1);

    _routes = List<AppRoute>.unmodifiable(<AppRoute>[...below, route]);
    notifyListeners();
  }

  void restoreRoutes(List<AppRoute> routes) {
    if (routes.isEmpty) {
      throw StateError('A window always shows a page');
    }
    for (final AppRoute route in routes) {
      _requireOpenable(route);
    }

    _routes = List<AppRoute>.unmodifiable(routes);
    notifyListeners();
  }

  void closeSavedForm() {
    _routes = List<AppRoute>.unmodifiable(_listRoutesBelowSavedForm());
    notifyListeners();
  }

  void replaceSavedForm(AppRoute destination) {
    _requireOpenable(destination);
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

  void _requireOpenable(AppRoute route) {
    if (!canOpen(route)) {
      throw StateError('This window cannot open ${route.runtimeType}');
    }
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
