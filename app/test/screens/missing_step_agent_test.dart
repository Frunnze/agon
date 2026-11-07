import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflow_agents.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/fake_task_work_links.dart';
import '../support/random_inputs.dart';
import '../support/recording_native_windows.dart';
import '../support/run_window_harness.dart';

const int _featurePipelineIndex = 2;
const String _missingStepError = 'has no agent';
const int _randomIdRange = 1 << 20;

final List<Run> _releaseRuns = <Run>[galleryRunningRun, galleryFailedRun];

WorkflowAgent _giveNewId(WorkflowAgent agent, String newIdText) {
  return WorkflowAgent(
    id: WorkflowAgentId(newIdText),
    name: agent.name,
    stepKind: agent.stepKind,
    kind: agent.kind,
    task: agent.task,
    runsOn: agent.runsOn,
    skills: agent.skills,
    usesAutomaticSkills: agent.usesAutomaticSkills,
    approvalPolicy: agent.approvalPolicy,
    position: agent.position,
  );
}

Workflow _withReleaseAgents(List<WorkflowAgent> agents) {
  return galleryWorkflows.first.withGraph(
    agents: agents,
    connections: connectInOrder(agents),
  );
}

Workflow _releaseChangedByAgent() {
  final List<WorkflowAgent> changedAgents = <WorkflowAgent>[];
  for (final WorkflowAgent agent in releaseAgents) {
    changedAgents.add(_giveNewId(agent, 'changed-${agent.name}'));
  }
  return _withReleaseAgents(changedAgents);
}

Workflow _randomRelease(Random random) {
  final List<WorkflowAgent> agents = <WorkflowAgent>[];
  for (final WorkflowAgent agent in releaseAgents) {
    final int choice = random.nextInt(3);
    if (choice == 0) {
      agents.add(agent);
    }
    if (choice == 1) {
      final String newIdText = 'changed-${random.nextInt(_randomIdRange)}';
      agents.add(_giveNewId(agent, newIdText));
    }
  }
  return _withReleaseAgents(agents);
}

RunStep _withAgentId(RunStep step, WorkflowAgentId? agentId) {
  return RunStep(
    name: step.name,
    agentId: agentId,
    runner: step.runner,
    status: step.status,
    startedAt: step.startedAt,
    finishedAt: step.finishedAt,
    result: step.result,
    outcome: step.outcome,
    loopSource: step.loopSource,
    earlierRounds: step.earlierRounds,
  );
}

WorkflowAgentId? _randomStepAgentId(Random random, RunStep step) {
  final int choice = random.nextInt(3);
  if (choice == 0) {
    return step.agentId;
  }
  if (choice == 1) {
    return WorkflowAgentId('gone-${random.nextInt(_randomIdRange)}');
  }
  return null;
}

Run _randomRun(Random random, Run run) {
  final List<RunStep> steps = <RunStep>[];
  for (final RunStep step in run.steps) {
    steps.add(_withAgentId(step, _randomStepAgentId(random, step)));
  }
  return run.withProgress(
    nextStatus: run.status,
    nextSteps: steps,
    nextFinishedAt: run.finishedAt,
  );
}

AppDependencies _buildDependencies({
  required Workflow release,
  required List<Run> runs,
}) {
  final Clock clock = FixedClock(galleryNow);
  final FakeWorkflowRepository workflowRepository = FakeWorkflowRepository(
    workflows: <Workflow>[release, ...galleryWorkflows.skip(1)],
    changes: galleryWorkflowChanges,
    clock: clock,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    draftTemplate: galleryWorkflows[_featurePipelineIndex],
    drafterDeviceId: GalleryDeviceIds.officeServer,
    draftStepDelay: Duration.zero,
    workspaceRepository: buildAcmeWorkspaceRepository(),
  );
  final FakeTaskRepository taskRepository = FakeTaskRepository(
    tasks: <Task>[...galleryTasks, ...galleryJobs],
    runs: runs,
    clock: clock,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    workflowRepository: workflowRepository,
  );
  return removeApprovals(
    replaceRepositories(
      buildGalleryDependencies(),
      workflowRepository: workflowRepository,
      taskRepository: taskRepository,
    ),
  );
}

void _expectStepsShownByName(Run run) {
  expect(find.textContaining(_missingStepError), findsNothing);
  for (final RunStep step in run.steps) {
    expect(find.text(step.name), findsWidgets);
  }
}

Future<void> _expectEveryRunScreenBuilds(
  WidgetTester tester, {
  required AppDependencies dependencies,
  required Run run,
}) async {
  await pumpApp(
    tester,
    size: desktopSize,
    route: TaskRunRoute(run.id),
    dependencies: dependencies,
  );
  expect(tester.takeException(), isNull);
  _expectStepsShownByName(run);

  await pumpApp(
    tester,
    size: desktopSize,
    route: ChatRoute(run.id),
    dependencies: dependencies,
  );
  expect(tester.takeException(), isNull);
  expect(find.textContaining(_missingStepError), findsNothing);

  await pumpRunWindow(
    tester,
    runId: run.id,
    dependencies: dependencies,
    onTopSwitch: RecordingOnTopSwitch(),
  );
  expect(tester.takeException(), isNull);
  _expectStepsShownByName(run);
}

void main() {
  testWidgets('a finished run of a workflow the agent changed still shows', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = _buildDependencies(
      release: _releaseChangedByAgent(),
      runs: galleryRuns,
    );

    await _expectEveryRunScreenBuilds(
      tester,
      dependencies: dependencies,
      run: galleryFailedRun,
    );
    await _expectEveryRunScreenBuilds(
      tester,
      dependencies: dependencies,
      run: galleryRunningRun,
    );
  });

  testWidgets(
    'test_find_run_step_agent_property_run_screens_show_missing_steps',
    (WidgetTester tester) async {
      final Random random = seededRandom(7311);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Run run = _randomRun(random, pickOne(random, _releaseRuns));
        final List<Run> runs = <Run>[run];
        for (final Run galleryRun in galleryRuns) {
          if (galleryRun.id != run.id) {
            runs.add(galleryRun);
          }
        }
        final AppDependencies dependencies = _buildDependencies(
          release: _randomRelease(random),
          runs: runs,
        );

        await _expectEveryRunScreenBuilds(
          tester,
          dependencies: dependencies,
          run: run,
        );
      }
    },
  );
}
