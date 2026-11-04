import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/rising_page.dart';
import 'package:agent_orchestration/shell/route_screens.dart';
import 'package:agent_orchestration/windows/run_window_opener.dart';

List<Page<Object?>> buildRoutePages({
  required List<AppRoute> routes,
  required AppDependencies dependencies,
  required AppNavigation navigation,
  required RunWindowOpener? runWindowOpener,
}) {
  final List<Page<Object?>> pages = <Page<Object?>>[];

  for (int index = 0; index < routes.length; index += 1) {
    final AppRoute route = routes[index];
    pages.add(
      RisingPage(
        key: ValueKey<(int, AppRoute)>((index, route)),
        child: buildRouteScreen(
          route: route,
          dependencies: dependencies,
          navigation: navigation,
          runWindowOpener: runWindowOpener,
        ),
      ),
    );
  }

  return pages;
}
