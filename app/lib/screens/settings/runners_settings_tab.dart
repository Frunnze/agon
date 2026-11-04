import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/page_metrics.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/label_chip.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';
import 'package:agent_orchestration/widgets/slots_indicator.dart';

const List<String> _columnLabels = <String>[
  'Runner',
  'Slots',
  'Link',
  'Status',
];

class RunnersSettingsTab extends StatelessWidget {
  const RunnersSettingsTab({
    required this.runnerRepository,
    required this.deviceRepository,
    required this.workspaceRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final RunnerRepository runnerRepository;
  final DeviceRepository deviceRepository;
  final WorkspaceRepository workspaceRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        runnerRepository,
        deviceRepository,
        workspaceRepository,
      ]),
      builder: _buildRunners,
    );
  }

  Widget _buildRunners(BuildContext context, Widget? _) {
    final List<Runner> runners = runnerRepository.listRunners();
    final String? thisRunnerProblem = runnerRepository.findThisRunnerProblem();

    if (runners.isEmpty) {
      return _buildWithoutRunners(thisRunnerProblem);
    }

    final AppServerStatus server = workspaceRepository.findAppServerStatus();
    final bool isServerDown = server.state == AppServerState.unreachable;
    final String countSummary = isServerDown
        ? describeReachableRunners(runners)
        : describeRunnerFleet(runners);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        Text(countSummary, style: AppTextStyles.bodyMuted),
        if (thisRunnerProblem != null)
          _buildThisRunnerProblem(thisRunnerProblem),
        if (isServerDown) _buildServerDownBanner(runners, server),
        ResponsiveList(
          columns: buildStandardColumns(_columnLabels),
          rows: <ListRowData>[
            for (final Runner runner in runners)
              _buildRow(runner, server.state),
          ],
        ),
      ], pageGap),
    );
  }

  Widget _buildWithoutRunners(String? thisRunnerProblem) {
    if (thisRunnerProblem != null) {
      return _buildThisRunnerProblem(thisRunnerProblem);
    }
    return const EmptyState(
      title: 'No runners yet',
      message:
          'Pair a computer as a runner in Your devices and it shows up '
          'here.',
      action: null,
    );
  }

  Widget _buildThisRunnerProblem(String problem) {
    final List<PlaceOffer>? offers = runnerRepository.findThisDeviceOffers();
    final bool canAddLocal =
        offers != null &&
        !offers.any(
          (PlaceOffer offer) => offer.place == AgentPlace.localProcess,
        );

    return RunnerProblemBanner(
      problem: problem,
      onRunLocally: canAddLocal ? () => _runAgentsLocally(offers) : null,
    );
  }

  void _runAgentsLocally(List<PlaceOffer> offers) {
    final List<AgentPlace> nextOffers = <AgentPlace>[
      for (final PlaceOffer offer in offers) offer.place,
      AgentPlace.localProcess,
    ];
    unawaited(runnerRepository.chooseAgentOffers(nextOffers));
  }

  Widget _buildServerDownBanner(List<Runner> runners, AppServerStatus server) {
    final List<String> waitingNames = <String>[
      for (final Runner runner in runners)
        if (findRunnerReach(runner, server.state) == RunnerReach.needsServer)
          deviceRepository.findDevice(runner.deviceId).name,
    ];

    return NoticeBanner(
      tone: BannerTone.attention,
      icon: AppIconKind.alert,
      title: "Can't reach the app server",
      body: <Widget>[
        Text(describeServerDownNotice(waitingNames)),
        Text(describeServerRetry(server), style: AppTextStyles.bodyMuted),
      ],
      actions: <Widget>[
        AppButton.secondary(
          label: 'Try now',
          icon: AppIconKind.retry,
          onPressed: () => unawaited(workspaceRepository.retryAppServer()),
        ),
      ],
    );
  }

  ListRowData _buildRow(Runner runner, AppServerState serverState) {
    final Device device = deviceRepository.findDevice(runner.deviceId);
    final RunnerReach reach = findRunnerReach(runner, serverState);

    return ListRowData(
      key: ValueKey<DeviceId>(runner.deviceId),
      main: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            device.name,
            style: AppTextStyles.bodyBold.merge(AppTextStyles.monospace),
          ),
          const SizedBox(height: AppSpacing.space1),
          ChipList(runner.labels),
        ],
      ),
      meta: _buildMeta(runner, device, reach, serverState),
      end: buildRunnerStatusLabel(runner: runner, reach: reach),
      onTap: () => navigation.openRoute(RunnerDetailRoute(runner.deviceId)),
    );
  }

  List<Widget> _buildMeta(
    Runner runner,
    Device device,
    RunnerReach reach,
    AppServerState serverState,
  ) {
    switch (reach) {
      case RunnerReach.reachable:
        return <Widget>[
          SlotsIndicator(total: runner.slotsTotal, busy: runner.slotsBusy),
          Text(describeRunnerLink(runner.link, serverState)),
        ];
      case RunnerReach.offline:
        final String lastSeen = describeLastSeen(device.lastSeen, clock.now());
        return <Widget>[
          const Text('None free'),
          Text('Last seen ${lastSeen.toLowerCase()}'),
        ];
      case RunnerReach.needsServer:
        return <Widget>[
          const Text('Unknown'),
          Text(describeRunnerLink(runner.link, serverState)),
        ];
    }
  }
}
