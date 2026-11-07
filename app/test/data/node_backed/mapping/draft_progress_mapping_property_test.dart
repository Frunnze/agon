import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/random_run_json.dart';
import '../../../support/random_inputs.dart';
import '../../../support/random_workflows.dart';

const int _largestRunCount = 6;

node.Run _buildRun(Random random, {required int number}) {
  final Map<String, Object?> runJson = randomRunJson(random);
  runJson['number'] = number;
  return node.Run.fromJson(runJson);
}

node.Run _buildRunWithoutRunners(Random random, {required int number}) {
  final Map<String, Object?> runJson = randomRunJson(random);
  final List<Object?> steps = <Object?>[];
  for (final Object? step in runJson['steps']! as List<Object?>) {
    final Map<String, Object?> stepJson = Map<String, Object?>.of(
      step! as Map<String, Object?>,
    );
    stepJson['runner'] = null;
    steps.add(stepJson);
  }
  runJson['number'] = number;
  runJson['steps'] = steps;
  return node.Run.fromJson(runJson);
}

List<node.Run> _buildRunsNumberedFromOne(Random random) {
  final int count = 1 + random.nextInt(_largestRunCount);
  final List<int> numbers = <int>[
    for (int number = 1; number <= count; number += 1) number,
  ];
  numbers.shuffle(random);
  return <node.Run>[
    for (final int number in numbers) _buildRun(random, number: number),
  ];
}

Workflow _buildShellWithAgents(Random random) {
  final Workflow shell = buildDraftShell(
    workflowId: WorkflowId(randomText(random)),
  );
  return Workflow(
    id: shell.id,
    name: shell.name,
    availability: shell.availability,
    agents: randomAgents(random),
    connections: shell.connections,
    signature: shell.signature,
  );
}

void main() {
  test('test_build_draft_shell_property_keeps_any_identifier', () {
    final Random random = seededRandom(72001);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String identifierText = randomText(random);

      final Workflow shell = buildDraftShell(
        workflowId: WorkflowId(identifierText),
      );

      expect(shell.id.value, identifierText);
      expect(shell.id, WorkflowId(identifierText));
    }
  });

  test('test_build_draft_shell_property_cannot_be_grown_in_place', () {
    final Random random = seededRandom(72002);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow shell = buildDraftShell(
        workflowId: WorkflowId(randomText(random)),
      );
      final WorkspaceScope availability = shell.availability;

      expect(
        () => shell.agents.add(randomAgent(random, i)),
        throwsUnsupportedError,
      );
      expect(shell.connections.clear, throwsUnsupportedError);
      expect(
        () => (availability as OnlyWorkspaces).workspaces.add(
          WorkspaceId(randomText(random)),
        ),
        throwsUnsupportedError,
      );
    }
  });

  test('test_find_latest_run_property_ignores_the_order_of_runs', () {
    final Random random = seededRandom(72003);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.Run> runs = _buildRunsNumberedFromOne(random);
      final List<node.Run> shuffled = List<node.Run>.of(runs);
      shuffled.shuffle(random);

      final node.Run? latest = findLatestRun(runs);
      final node.Run? latestOfShuffled = findLatestRun(shuffled);

      expect(latest, isNotNull);
      expect(latest, same(latestOfShuffled));
      expect(latest!.number, runs.length);
    }
  });

  test('test_find_latest_run_property_a_newer_run_takes_over', () {
    final Random random = seededRandom(72004);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.Run> runs = _buildRunsNumberedFromOne(random);
      final node.Run newerRun = _buildRun(random, number: runs.length + 1);
      final int insertAt = random.nextInt(runs.length + 1);
      final List<node.Run> withNewer = List<node.Run>.of(runs);
      withNewer.insert(insertAt, newerRun);

      expect(findLatestRun(withNewer), same(newerRun));
    }
  });

  test('test_find_drafter_device_id_property_older_runs_never_change_it', () {
    final Random random = seededRandom(72005);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.Run> runs = _buildRunsNumberedFromOne(random);
      final node.Run olderRun = _buildRun(random, number: 0);
      final List<node.Run> withOlder = <node.Run>[olderRun, ...runs];

      expect(findDrafterDeviceId(withOlder), findDrafterDeviceId(runs));
    }
  });

  test('test_find_drafter_device_id_property_ignores_the_order_of_runs', () {
    final Random random = seededRandom(72006);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.Run> runs = _buildRunsNumberedFromOne(random);
      final List<node.Run> shuffled = List<node.Run>.of(runs);
      shuffled.shuffle(random);

      expect(findDrafterDeviceId(shuffled), findDrafterDeviceId(runs));
    }
  });

  test('test_build_working_draft_progress_property_waits_on_one_steps_'
      'placeholder', () {
    final Random random = seededRandom(72007);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.Run> runs = _buildRunsNumberedFromOne(random);
      final AgentKind drafterKind = pickOne(random, AgentKind.values);

      final WorkflowDraftProgress? progress = buildWorkingDraftProgress(
        runs: runs,
        draftShell: _buildShellWithAgents(random),
        drafterKind: drafterKind,
      );

      if (findDrafterDeviceId(runs) == null) {
        expect(progress, isNull);
        continue;
      }
      expect(progress!.drafterKind, drafterKind);
      expect(progress.pendingAgents, hasLength(1));
      expect(progress.pendingAgents.single.name, pendingDraftStepsName);
      expect(progress.isFinished, isFalse);
      expect(progress.pendingAgents.clear, throwsUnsupportedError);
    }
  });

  test('test_build_working_draft_progress_property_places_steps_below_'
      'every_agent', () {
    final Random random = seededRandom(72008);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.Run> runs = _buildRunsNumberedFromOne(random);
      final Workflow shell = _buildShellWithAgents(random);

      final WorkflowDraftProgress? progress = buildWorkingDraftProgress(
        runs: runs,
        draftShell: shell,
        drafterKind: pickOne(random, AgentKind.values),
      );

      if (progress == null) {
        continue;
      }
      final CanvasPosition position = progress.pendingAgents.single.position;
      for (final WorkflowAgent agent in shell.agents) {
        expect(position.vertical, greaterThan(agent.position.vertical));
      }
      expect(progress.workflow, same(shell));
    }
  });

  test('test_build_finished_draft_progress_property_agrees_with_working_'
      'progress', () {
    final Random random = seededRandom(72009);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.Run> runs = _buildRunsNumberedFromOne(random);
      final Workflow drafted = _buildShellWithAgents(random);
      final AgentKind drafterKind = pickOne(random, AgentKind.values);
      final WorkflowDraftProgress? working = buildWorkingDraftProgress(
        runs: runs,
        draftShell: drafted,
        drafterKind: drafterKind,
      );
      if (working == null) {
        continue;
      }

      final WorkflowDraftProgress finished = buildFinishedDraftProgress(
        drafted: drafted,
        runs: runs,
        drafterKind: drafterKind,
      );

      expect(finished.drafterDeviceId, working.drafterDeviceId);
      expect(finished.drafterKind, drafterKind);
      expect(finished.pendingAgents, isEmpty);
      expect(finished.workflow.agents, drafted.agents);
    }
  });

  test('test_build_finished_draft_progress_property_runnerless_runs_name_'
      'the_workflow', () {
    final Random random = seededRandom(72010);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow shell = _buildShellWithAgents(random);
      final Workflow drafted = Workflow(
        id: shell.id,
        name: 'draft-${randomText(random)}',
        availability: shell.availability,
        agents: shell.agents,
        connections: shell.connections,
        signature: shell.signature,
      );
      final int runCount = random.nextInt(_largestRunCount);
      final List<node.Run> runs = <node.Run>[
        for (int number = 0; number < runCount; number += 1)
          _buildRunWithoutRunners(random, number: number),
      ];

      expect(
        () => buildFinishedDraftProgress(
          drafted: drafted,
          runs: runs,
          drafterKind: pickOne(random, AgentKind.values),
        ),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains(drafted.name),
          ),
        ),
      );
    }
  });
}
