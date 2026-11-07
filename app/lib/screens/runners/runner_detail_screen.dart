import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/host_text.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/runners.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/shared/runner_link_route.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const String _pauseLabel = 'Pause new runs';
const String _resumeLabel = 'Resume new runs';

class RunnerDetailScreen extends StatelessWidget {
  const RunnerDetailScreen({
    required this.deviceId,
    required this.runnerRepository,
    required this.agentLoginRepository,
    required this.deviceRepository,
    required this.workspaceRepository,
    required this.taskRepository,
    required this.workflowRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final DeviceId deviceId;
  final RunnerRepository runnerRepository;
  final AgentLoginRepository agentLoginRepository;
  final DeviceRepository deviceRepository;
  final WorkspaceRepository workspaceRepository;
  final TaskRepository taskRepository;
  final WorkflowRepository workflowRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        runnerRepository,
        deviceRepository,
        workspaceRepository,
        taskRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final Runner runner = runnerRepository.findRunner(deviceId);
    final Device device = deviceRepository.findDevice(deviceId);
    final RunnerReach reach = findRunnerReach(
      runner,
      workspaceRepository.findAppServerStatus().state,
    );
    final String lastSeen = describeLastSeen(device.lastSeen, clock.now());
    final Device thisDevice = deviceRepository.currentDevice();
    final bool isThisDevice = device.id == thisDevice.id;
    final List<PlaceOffer>? thisDeviceOffers = isThisDevice
        ? runnerRepository.findThisDeviceOffers()
        : null;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: device.name,
          backLink: BackLink(
            label: 'Devices',
            onPressed: navigation.closeRoute,
          ),
          summary: <TextSegment>[
            TextSegment(
              describeRunnerSummary(
                runner: runner,
                reach: reach,
                lastSeen: lastSeen.toLowerCase(),
              ),
            ),
          ],
          actions: <Widget>[_buildPauseButton(context, runner, device.name)],
        ),
        if (!isThisDevice)
          buildRunnerLinkRoute(
            startName: thisDevice.name,
            endName: device.name,
            link: runner.link,
          ),
        SplitLayout(
          start: PageSection(
            title: 'How runs work here',
            children: <Widget>[_buildFacts(runner, device)],
          ),
          end: PageSection(
            title: 'Running now',
            children: <Widget>[_buildRunningSteps()],
          ),
        ),
        if (thisDeviceOffers != null)
          AgentOffersSection(
            offers: thisDeviceOffers,
            onChanged: (List<AgentPlace> offers) =>
                unawaited(_chooseAgentOffers(context, offers)),
          ),
        if (thisDeviceOffers != null)
          for (final PlaceOffer offer in thisDeviceOffers)
            AgentLoginSection(
              key: ValueKey<AgentPlace>(offer.place),
              place: offer.place,
              repository: agentLoginRepository,
            ),
      ],
    );
  }

  Widget _buildPauseButton(
    BuildContext context,
    Runner runner,
    String deviceName,
  ) {
    if (runner.acceptingNewRuns) {
      return AppButton.secondary(
        label: _pauseLabel,
        onPressed: () => unawaited(_pauseNewRuns(context, deviceName)),
      );
    }
    return AppButton.secondary(
      label: _resumeLabel,
      icon: AppIconKind.play,
      onPressed: () => unawaited(_resumeNewRuns(context, deviceName)),
    );
  }

  Future<void> _pauseNewRuns(BuildContext context, String deviceName) {
    return runShowingRefusal(
      context: context,
      title: deviceName,
      actionLabel: _pauseLabel,
      action: () => runnerRepository.pauseRunner(deviceId),
    );
  }

  Future<void> _resumeNewRuns(BuildContext context, String deviceName) {
    return runShowingRefusal(
      context: context,
      title: deviceName,
      actionLabel: _resumeLabel,
      action: () => runnerRepository.resumeRunner(deviceId),
    );
  }

  Future<void> _chooseAgentOffers(
    BuildContext context,
    List<AgentPlace> offers,
  ) {
    return runShowingRefusal(
      context: context,
      title: agentOffersTitle,
      actionLabel: changeSettingLabel,
      action: () => runnerRepository.chooseAgentOffers(offers),
    );
  }

  Widget _buildFacts(Runner runner, Device device) {
    final bool isThisDevice = device.id == deviceRepository.currentDevice().id;

    return FactList(
      facts: <Fact>[
        Fact.chips(term: 'Labels', chips: runner.labels),
        if (!isThisDevice)
          Fact(
            term: agentPlaceTitle,
            description: <TextSegment>[
              TextSegment(describeRunnerOffers(runner.offers)),
            ],
          ),
        if (runner.offers.contains(AgentPlace.container))
          Fact(
            term: containerNetworkTitle,
            description: describeContainerNetwork(runner.allowedHosts),
          ),
        Fact(
          term: 'Device key',
          description: <TextSegment>[TextSegment(device.keyKind.label)],
        ),
      ],
    );
  }

  Widget _buildRunningSteps() {
    final List<RunningStep> runningSteps = findStepsRunningOn(
      deviceId: deviceId,
      taskRepository: taskRepository,
    );
    if (runningSteps.isEmpty) {
      return const Text(
        'Nothing is running here.',
        style: AppTextStyles.smallMuted,
      );
    }

    return ResponsiveList.plain(
      rows: <ListRowData>[
        for (final RunningStep running in runningSteps)
          _buildRunningRow(running),
      ],
    );
  }

  ListRowData _buildRunningRow(RunningStep running) {
    final String doer = describeDoer(
      running.task.doer,
      workflowRepository.listWorkflows(),
    );
    final DateTime startedAt = running.step.startedAt ?? running.run.startedAt;
    final String duration = describeWholeMinutes(
      clock.now().difference(startedAt),
    );

    return ListRowData(
      key: ValueKey<String>('${running.run.id}-${running.step.name}'),
      main: ListRowMain(
        title: running.task.title,
        subtitle: <TextSegment>[
          TextSegment('$doer · ${running.step.name} · $duration'),
        ],
      ),
      end: const StatusLabel(
        text: 'Running',
        tone: StatusTone.normal,
        icon: AppIconKind.spinner,
      ),
      onTap: () => navigation.openRoute(TaskRunRoute(running.run.id)),
    );
  }
}
