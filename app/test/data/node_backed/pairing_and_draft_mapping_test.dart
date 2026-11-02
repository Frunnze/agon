import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/random_account_json.dart';
import '../../bridge/support/random_run_json.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../support/random_inputs.dart';

List<node.Run> _randomRuns(Random random) {
  return <node.Run>[
    for (final Object? json in randomListOf(random, randomRunJson))
      node.Run.fromJson(json),
  ];
}

Workflow _randomShell(Random random) {
  return buildDraftShell(workflowId: WorkflowId(randomUuidText(random)));
}

void main() {
  test('test_map_pairing_session_from_node_property_keeps_countdown', () {
    final Random random = seededRandom(9401);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.PairingRequestScreen screen =
          node.PairingRequestScreen.fromJson(
            randomPairingRequestScreenJson(random),
          );
      final PairingSession session = mapPairingSessionFromNode(screen);
      expect(session.code, screen.displayCode);
      expect(session.expiresAt, screen.expiresAt);
      expect(session.createdAt, screen.startedAt);
    }
  });

  test('test_map_pairing_request_from_node_property_keeps_device', () {
    final Random random = seededRandom(9402);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.JoiningDevice joining = node.JoiningDevice.fromJson(
        randomJoiningDeviceJson(random),
      );
      final String codeUsed = randomText(random);
      final PairingRequest request = mapPairingRequestFromNode(
        joining,
        codeUsed: codeUsed,
      );
      expect(request.deviceName, joining.name);
      expect(mapDeviceRoleToNode(request.role), joining.role);
      expect(request.keyKind.name, joining.keyKind.name);
      expect(request.fingerprintWords, joining.fingerprintWords);
      expect(request.codeUsed, codeUsed);
      expect(request.link, isNull);
    }
  });

  test('test_map_pairing_outcome_from_node_property_keeps_account', () {
    final Random random = seededRandom(9403);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AccountSummary account = node.AccountSummary.fromJson(
        randomAccountSummaryJson(random),
      );
      final List<String> labels = <String>[randomText(random)];
      final String? approverName = random.nextBool()
          ? null
          : randomText(random);
      final PairingOutcome outcome = mapPairingOutcomeFromNode(
        account,
        runnerLabels: labels,
        approverName: approverName,
      );
      expect(outcome.deviceName, account.device.name);
      expect(mapDeviceRoleToNode(outcome.role), account.device.role);
      expect(outcome.workspaceNames, <String>[
        for (final node.Workspace workspace in account.workspaces)
          workspace.name,
      ]);
      expect(outcome.runnerLabels, labels);
      expect(outcome.approverName, approverName);
    }
  });

  test('test_build_draft_shell_property_is_empty_and_unsigned', () {
    final Random random = seededRandom(9404);
    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowId workflowId = WorkflowId(randomUuidText(random));
      final Workflow shell = buildDraftShell(workflowId: workflowId);
      expect(shell.id, workflowId);
      expect(shell.name, isEmpty);
      final WorkspaceScope availability = shell.availability;
      expect(availability, isA<OnlyWorkspaces>());
      expect((availability as OnlyWorkspaces).workspaces, isEmpty);
      expect(shell.agents, isEmpty);
      expect(shell.connections, isEmpty);
      expect(shell.signature, isNull);
    }
  });

  test('test_find_latest_run_property_highest_number_or_none', () {
    final Random random = seededRandom(9409);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.Run> runs = _randomRuns(random);
      final node.Run? latest = findLatestRun(runs);
      if (runs.isEmpty) {
        expect(latest, isNull);
        continue;
      }
      expect(runs, contains(latest));
      for (final node.Run run in runs) {
        expect(run.number, lessThanOrEqualTo(latest!.number));
      }
    }
  });

  test('test_find_drafter_device_id_property_reads_latest_run', () {
    final Random random = seededRandom(9406);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.Run> runs = _randomRuns(random);
      final DeviceId? drafter = findDrafterDeviceId(runs);
      if (runs.isEmpty) {
        expect(drafter, isNull);
        continue;
      }
      node.Run latest = runs.first;
      for (final node.Run run in runs) {
        if (run.number > latest.number) {
          latest = run;
        }
      }
      final List<DeviceId> runners = <DeviceId>[
        for (final node.RunStep step in latest.steps)
          if (step.runner case final DeviceId runner) runner,
      ];
      expect(drafter, runners.isEmpty ? isNull : runners.first);
    }
  });

  test('test_build_working_draft_progress_property_waits_for_runner', () {
    final Random random = seededRandom(9407);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.Run> runs = _randomRuns(random);
      final Workflow shell = _randomShell(random);
      final DeviceId? drafter = findDrafterDeviceId(runs);
      final WorkflowDraftProgress? progress = buildWorkingDraftProgress(
        runs: runs,
        draftShell: shell,
        drafterKind: AgentKind.codex,
      );
      if (drafter == null) {
        expect(progress, isNull);
        continue;
      }
      expect(progress?.drafterDeviceId, drafter);
      expect(progress?.drafterKind, AgentKind.codex);
      expect(progress?.isFinished, isFalse);
      expect(progress?.workflow, same(shell));
    }
  });

  test('test_build_finished_draft_progress_property_is_finished', () {
    final Random random = seededRandom(9408);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.Run> runs = _randomRuns(random);
      final Workflow drafted = _randomShell(random);
      final DeviceId? drafter = findDrafterDeviceId(runs);
      if (drafter == null) {
        expect(
          () => buildFinishedDraftProgress(
            drafted: drafted,
            runs: runs,
            drafterKind: AgentKind.geminiCli,
          ),
          throwsStateError,
        );
        continue;
      }
      final WorkflowDraftProgress progress = buildFinishedDraftProgress(
        drafted: drafted,
        runs: runs,
        drafterKind: AgentKind.geminiCli,
      );
      expect(progress.isFinished, isTrue);
      expect(progress.workflow, same(drafted));
      expect(progress.drafterDeviceId, drafter);
    }
  });
}
