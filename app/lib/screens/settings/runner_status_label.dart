import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

StatusLabel buildRunnerStatusLabel({
  required Runner runner,
  required RunnerReach reach,
}) {
  switch (reach) {
    case RunnerReach.reachable:
      if (!runner.acceptingNewRuns) {
        return const StatusLabel(
          text: 'Paused',
          tone: StatusTone.muted,
          icon: AppIconKind.clock,
        );
      }
      return const StatusLabel(
        text: 'Online',
        tone: StatusTone.normal,
        icon: AppIconKind.online,
      );
    case RunnerReach.offline:
      return const StatusLabel(
        text: 'Offline',
        tone: StatusTone.muted,
        icon: AppIconKind.offline,
      );
    case RunnerReach.needsServer:
      return const StatusLabel(
        text: 'Unreachable',
        tone: StatusTone.muted,
        icon: AppIconKind.offline,
      );
  }
}
