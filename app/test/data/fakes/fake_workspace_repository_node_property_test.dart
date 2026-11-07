import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import '../node_backed/support/simulated_catalog_node.dart';
import 'support/refusals.dart';
import 'support/workspace_inputs.dart';

const int _sequenceIterations = 30;
const int _longestSequence = 8;
const int _largestSeededCount = 3;
const Duration _retryInterval = Duration(seconds: 30);
const WorkspaceId _missingWorkspaceId = WorkspaceId('workspace-missing');

typedef _Pair = ({
  FakeWorkspaceRepository fake,
  NodeBackedWorkspaceRepository nodeBacked,
});

enum _Operation { create, switchTo, delete, policy, protect, backup }

typedef _PlannedStep = ({
  _Operation operation,
  int at,
  String name,
  ApprovalPolicy policy,
  List<String> patterns,
});

bool _isWorkspaceRefusal(Object error) {
  return error is StateError ||
      error is ArgumentError ||
      error is RecordNotFound;
}

List<String> _describe(WorkspaceRepository repository) {
  final AppServerGroup group = repository.findAppServerGroup();
  return <String>[
    for (final Workspace workspace in repository.listWorkspaces())
      '${workspace.name} ${workspace.approvalPolicy.name}',
    'current ${repository.currentWorkspace().name}',
    'standing ${group.thisDeviceStanding.name}',
    ...describeServerMembers(group),
  ];
}

Future<_Pair> _buildPair(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final int seededCount = 1 + random.nextInt(_largestSeededCount);
  for (int i = 0; i < seededCount; i += 1) {
    simulated.addWorkspace('seeded-$i');
  }
  simulated.serverGroup.canKeepBackup = random.nextBool();
  if (random.nextBool()) {
    simulated.serverGroup.foundGroup();
  }
  final NodeBackedWorkspaceRepository nodeBacked =
      NodeBackedWorkspaceRepository(
        channel: simulated.channel,
        clock: FixedClock(galleryNow),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await nodeBacked.load();
  final FakeWorkspaceRepository fake = FakeWorkspaceRepository(
    workspaces: nodeBacked.listWorkspaces(),
    currentWorkspaceId: nodeBacked.currentWorkspace().id,
    appServerStatus: nodeBacked.findAppServerStatus(),
    appServerGroup: nodeBacked.findAppServerGroup(),
    currentDeviceId: const DeviceId(simulatedDeviceId),
    clock: FixedClock(galleryNow),
  );
  return (fake: fake, nodeBacked: nodeBacked);
}

WorkspaceId _pickWorkspaceId(WorkspaceRepository repository, int at) {
  final List<Workspace> listed = repository.listWorkspaces();
  if (at >= listed.length) {
    return _missingWorkspaceId;
  }
  return listed[at].id;
}

_PlannedStep _planStep(Random random, _Pair pair, _Operation focus) {
  final int at = random.nextInt(pair.fake.listWorkspaces().length + 1);
  final _Operation operation = random.nextInt(3) == 0
      ? pickOne(random, _Operation.values)
      : focus;
  return (
    operation: operation,
    at: at,
    name: randomWorkspaceName(random),
    policy: pickOne(random, ApprovalPolicy.values),
    patterns: randomPatterns(random),
  );
}

Future<Object?> _changeBackup(WorkspaceRepository target) {
  final ThisDeviceStanding standing = target
      .findAppServerGroup()
      .thisDeviceStanding;
  if (standing == ThisDeviceStanding.none) {
    return target.startServerBackup();
  }
  return target.stopServerBackup();
}

Future<Object?> _applyStep(WorkspaceRepository target, _PlannedStep step) {
  final WorkspaceId workspaceId = _pickWorkspaceId(target, step.at);
  return switch (step.operation) {
    _Operation.create => target.createWorkspace(name: step.name),
    _Operation.switchTo => target.switchWorkspace(workspaceId),
    _Operation.delete => target.deleteWorkspace(workspaceId),
    _Operation.policy => target.changeApprovalPolicy(
      workspaceId: workspaceId,
      approvalPolicy: step.policy,
    ),
    _Operation.protect => target.saveProtectedFiles(
      workspaceId: workspaceId,
      patterns: step.patterns,
    ),
    _Operation.backup => _changeBackup(target),
  };
}

Future<void> _checkAgreement({
  required _Operation focus,
  required int seed,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < _sequenceIterations; i += 1) {
    final _Pair pair = await _buildPair(random);
    final int stepCount = 1 + random.nextInt(_longestSequence);

    for (int stepIndex = 0; stepIndex < stepCount; stepIndex += 1) {
      final _PlannedStep step = _planStep(random, pair, focus);
      final bool isFakeRefused = await isRefused(
        () => _applyStep(pair.fake, step),
        isRefusal: _isWorkspaceRefusal,
      );
      final bool isNodeRefused = await isRefused(
        () => _applyStep(pair.nodeBacked, step),
        isRefusal: _isWorkspaceRefusal,
      );

      expect(isFakeRefused, isNodeRefused, reason: '$step');
      expect(
        _describe(pair.fake),
        orderedEquals(_describe(pair.nodeBacked)),
        reason: '$step',
      );
    }
  }
}

void main() {
  test('test_create_workspace_property_agrees_with_the_node', () async {
    await _checkAgreement(focus: _Operation.create, seed: 68201);
  });

  test('test_switch_workspace_property_agrees_with_the_node', () async {
    await _checkAgreement(focus: _Operation.switchTo, seed: 68202);
  });

  test('test_delete_workspace_property_agrees_with_the_node', () async {
    await _checkAgreement(focus: _Operation.delete, seed: 68203);
  });

  test('test_change_approval_policy_property_agrees_with_node', () async {
    await _checkAgreement(focus: _Operation.policy, seed: 68204);
  });

  test('test_save_protected_files_property_agrees_with_node', () async {
    await _checkAgreement(focus: _Operation.protect, seed: 68205);
  });

  test('test_start_server_backup_property_agrees_with_the_node', () async {
    await _checkAgreement(focus: _Operation.backup, seed: 68206);
  });
}
