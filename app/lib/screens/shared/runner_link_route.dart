import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/widgets/route_line.dart';
import 'package:agent_orchestration/widgets/route_line_painter.dart';

const String unknownLinkBadgeLabel = 'Encrypted';

RouteLine buildPairingLinkRoute({
  required String startName,
  required String endName,
  required RunnerLink? link,
}) {
  if (link == null) {
    return RouteLine(
      startName: startName,
      endName: endName,
      path: RoutePath.direct,
      badgeLabel: unknownLinkBadgeLabel,
      badgeIcon: AppIconKind.lock,
    );
  }
  return buildRunnerLinkRoute(
    startName: startName,
    endName: endName,
    link: link,
  );
}

RouteLine buildRunnerLinkRoute({
  required String startName,
  required String endName,
  required RunnerLink link,
}) {
  switch (link) {
    case RunnerLink.direct:
      return RouteLine(
        startName: startName,
        endName: endName,
        path: RoutePath.direct,
        badgeLabel: 'Direct · encrypted',
        badgeIcon: AppIconKind.lock,
      );
    case RunnerLink.localNetwork:
      return RouteLine(
        startName: startName,
        endName: endName,
        path: RoutePath.direct,
        badgeLabel: 'Same network · encrypted',
        badgeIcon: AppIconKind.lock,
      );
    case RunnerLink.relay:
      return RouteLine(
        startName: startName,
        endName: endName,
        path: RoutePath.relay,
        badgeLabel: 'Relay · encrypted',
        badgeIcon: AppIconKind.lock,
      );
    case RunnerLink.unreachable:
      return RouteLine(
        startName: startName,
        endName: endName,
        path: RoutePath.broken,
        badgeLabel: 'Reconnecting',
        badgeIcon: AppIconKind.spinner,
      );
  }
}
