import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/screens/runners.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

const String _serverDownTitle = "Can't reach the app server";
const String _tryNowLabel = 'Try now';

String? describeRunnerSummary({
  required List<Runner> runners,
  required AppServerState serverState,
}) {
  if (runners.isEmpty) {
    return null;
  }
  if (serverState == AppServerState.unreachable) {
    return 'Runners: ${describeReachableRunners(runners)}';
  }
  return 'Runners: ${describeRunnerFleet(runners)}';
}

class RunnerNotices {
  const RunnerNotices({
    required this.runnerRepository,
    required this.deviceRepository,
    required this.workspaceRepository,
  });

  final RunnerRepository runnerRepository;
  final DeviceRepository deviceRepository;
  final WorkspaceRepository workspaceRepository;

  List<Widget> buildNotices(BuildContext context) {
    final String? thisRunnerProblem = runnerRepository.findThisRunnerProblem();
    final List<Runner> runners = runnerRepository.listRunners();
    final AppServerStatus server = workspaceRepository.findAppServerStatus();
    final bool isServerDown = server.state == AppServerState.unreachable;

    return <Widget>[
      if (thisRunnerProblem != null)
        _buildThisRunnerProblem(context, thisRunnerProblem),
      if (isServerDown && runners.isNotEmpty)
        _buildServerDownBanner(context, runners, server),
    ];
  }

  Widget _buildThisRunnerProblem(BuildContext context, String problem) {
    final List<PlaceOffer>? offers = runnerRepository.findThisDeviceOffers();
    final bool canAddLocal =
        offers != null &&
        !offers.any(
          (PlaceOffer offer) => offer.place == AgentPlace.localProcess,
        );

    return RunnerProblemBanner(
      problem: problem,
      onRunLocally: canAddLocal
          ? () => unawaited(_runAgentsLocally(context, offers))
          : null,
    );
  }

  Future<void> _runAgentsLocally(
    BuildContext context,
    List<PlaceOffer> offers,
  ) {
    final List<AgentPlace> nextOffers = <AgentPlace>[
      for (final PlaceOffer offer in offers) offer.place,
      AgentPlace.localProcess,
    ];
    return runShowingRefusal(
      context: context,
      title: runnerProblemTitle,
      actionLabel: runLocallyLabel,
      action: () => runnerRepository.chooseAgentOffers(nextOffers),
    );
  }

  Future<void> _retryAppServer(BuildContext context) {
    return runShowingRefusal(
      context: context,
      title: _serverDownTitle,
      actionLabel: _tryNowLabel,
      action: workspaceRepository.retryAppServer,
    );
  }

  Widget _buildServerDownBanner(
    BuildContext context,
    List<Runner> runners,
    AppServerStatus server,
  ) {
    final List<String> waitingNames = <String>[
      for (final Runner runner in runners)
        if (findRunnerReach(runner, server.state) == RunnerReach.needsServer)
          deviceRepository.findDevice(runner.deviceId).name,
    ];

    return NoticeBanner(
      tone: BannerTone.attention,
      icon: AppIconKind.alert,
      title: _serverDownTitle,
      body: <Widget>[
        Text(describeServerDownNotice(waitingNames)),
        Text(describeServerRetry(server), style: AppTextStyles.bodyMuted),
      ],
      actions: <Widget>[
        AppButton.secondary(
          label: _tryNowLabel,
          icon: AppIconKind.retry,
          onPressed: () => unawaited(_retryAppServer(context)),
        ),
      ],
    );
  }
}
