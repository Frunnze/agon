import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';
import '../support/sample_runners.dart';

const DeviceId _thisDeviceId = GalleryDeviceIds.airLaptop;
const DeviceId _otherRunnerId = GalleryDeviceIds.macStudio;
const String _otherRunnerName = 'mac-studio';
const String _loginFailure = 'Not logged in · Please run /login';

Run _failRun({required DeviceId runner, required String reason}) {
  final Run base = galleryFailedRun;
  return Run(
    id: base.id,
    taskId: base.taskId,
    number: base.number,
    status: base.status,
    steps: base.steps,
    log: base.log,
    chat: base.chat,
    failure: RunFailure(
      stepName: base.failure!.stepName,
      runner: runner,
      reason: reason,
      retryRunsOnSameRunner: false,
    ),
    link: base.link,
    linkLostAt: base.linkLostAt,
    agentSession: base.agentSession,
    worktreeBranch: base.worktreeBranch,
    startedBy: base.startedBy,
    startedAt: base.startedAt,
    finishedAt: base.finishedAt,
    loopRounds: const <LoopRounds>[],
    notes: const <RunNote>[],
  );
}

Future<AppNavigation> _openFailedRun(
  WidgetTester tester, {
  required Run run,
}) async {
  final AppDependencies dependencies = buildGalleryDependencies();
  final List<Run> runs = <Run>[
    for (final Run galleryRun in galleryRuns)
      if (galleryRun.id == run.id) run else galleryRun,
  ];
  await tester.pumpWidget(const SizedBox.shrink());
  return pumpApp(
    tester,
    size: desktopSize,
    route: TaskRunRoute(run.id),
    dependencies: replaceRepositories(
      dependencies,
      taskRepository: FakeTaskRepository(
        tasks: <Task>[...galleryTasks, ...galleryJobs],
        runs: runs,
        clock: dependencies.clock,
        currentDeviceId: _thisDeviceId,
        workflowRepository:
            dependencies.workflowRepository as FakeWorkflowRepository,
      ),
      runnerRepository: FakeRunnerRepository(
        runners: <Runner>[
          ...galleryRunners,
          buildOnlineRunnerOn(_thisDeviceId),
        ],
        thisDeviceOffers: const <PlaceOffer>[
          PlaceOffer(place: AgentPlace.container, problem: null),
        ],
        thisRunnerProblem: null,
      ),
    ),
  );
}

void main() {
  testWidgets('test_run_failure_property_login_failures_point_to_runner', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9601);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isThisDevice = random.nextBool();
      final DeviceId runner = isThisDevice ? _thisDeviceId : _otherRunnerId;
      final String reason = '${randomText(random)} $_loginFailure';

      await _openFailedRun(
        tester,
        run: _failRun(runner: runner, reason: reason),
      );

      final String hint = isThisDevice
          ? thisComputerLoginHint
          : describeOtherRunnerLoginHint(_otherRunnerName);
      expect(find.text(hint), findsOneWidget);
      expect(
        find.text(connectClaudeCodeLabel),
        isThisDevice ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_run_failure_property_other_failures_point_nowhere', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9602);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String reason = 'xcodebuild stopped ${randomWordPhrase(random)}';

      await _openFailedRun(
        tester,
        run: _failRun(runner: _thisDeviceId, reason: reason),
      );

      expect(find.text(thisComputerLoginHint), findsNothing);
      expect(find.text(connectClaudeCodeLabel), findsNothing);
    }
  });

  testWidgets('test_connect_claude_code_property_opens_this_runner_page', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _openFailedRun(
      tester,
      run: _failRun(runner: _thisDeviceId, reason: _loginFailure),
    );

    await tapVisible(tester, find.text(connectClaudeCodeLabel));
    await pumpFrames(tester);

    final AppRoute shown = navigation.currentRoute;
    expect(shown, isA<RunnerDetailRoute>());
    expect((shown as RunnerDetailRoute).deviceId, _thisDeviceId);
  });
}
