import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/approval_inputs.dart';
import 'support/node_backed_approval_rig.dart';

const String _prefix = 'test_node_backed_approval_repository';
const int _sequenceIterations = 40;
const int _longestSequence = 6;

Future<ApprovalRig> _buildLoadedRig(Random random) async {
  final ApprovalRig rig = ApprovalRig();
  rig.addApprovals(random);
  await rig.repository.load();
  return rig;
}

FakeApprovalRepository _buildTwinFake(Random random, ApprovalRig rig) {
  return FakeApprovalRepository(
    approvals: rig.repository.listApprovals(),
    clock: FixedClock(randomUtcMoment(random)),
    currentDeviceId: approvalTestDevice,
  );
}

Future<void> _decideOnBoth(
  Random random,
  ApprovalRig rig,
  FakeApprovalRepository fake,
) async {
  final List<ApprovalRequest> pending = fake.listPendingApprovals();
  if (pending.isEmpty) {
    return;
  }
  final ApprovalId approvalId = pickOne(random, pending).id;
  final ApprovalDecision decision = pickOne(random, ApprovalDecision.values);
  await rig.repository.decideApproval(approvalId, decision);
  await fake.decideApproval(approvalId, decision);
}

void main() {
  test('${_prefix}_new_property_starts_empty_and_sends_nothing', () async {
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = ApprovalRig();
      await pumpEventQueue();

      expect(rig.repository.listApprovals(), isEmpty);
      expect(rig.repository.listPendingApprovals(), isEmpty);
      expect(rig.node.receivedCommands, isEmpty);
      expect(rig.notifications.count, 0);
    }
  });

  test('${_prefix}_new_property_finds_nothing_before_loading', () {
    final Random random = seededRandom(75701);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRig rig = ApprovalRig();
      final String approvalId = rig.node.addApprovalFromElsewhere(random);

      expect(
        () => rig.repository.findApproval(ApprovalId(approvalId)),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('${_prefix}_new_property_repositories_keep_their_own_list', () async {
    final Random random = seededRandom(75702);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig loaded = await _buildLoadedRig(random);
      final ApprovalRig untouched = ApprovalRig();
      untouched.addApprovals(random);

      expect(
        listApprovalIdentifiers(loaded.repository.listApprovals()),
        loaded.node.approvals.keys,
      );
      expect(untouched.repository.listApprovals(), isEmpty);
      expect(untouched.node.receivedCommands, isEmpty);
    }
  });

  test('${_prefix}_list_approvals_property_mirrors_the_node', () async {
    final Random random = seededRandom(75703);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);

      final List<ApprovalRequest> approvals = rig.repository.listApprovals();

      expect(listApprovalIdentifiers(approvals), rig.node.approvals.keys);
      for (final ApprovalRequest approval in approvals) {
        final Map<String, Object?> wire =
            rig.node.approvals[approval.id.value]!;
        expect(approval.isPending, wire['decision'] == null);
        expect(approval.requestedBy.value, wire['requested_by']);
        expect(approval.runId?.value, wire['run_id']);
      }
    }
  });

  test('${_prefix}_list_approvals_property_cannot_be_changed', () async {
    final Random random = seededRandom(75704);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);

      expect(
        () =>
            rig.repository.listApprovals().add(randomPendingApproval(random)),
        throwsUnsupportedError,
      );
    }
  });

  test('${_prefix}_list_approvals_property_reads_without_the_node', () async {
    final Random random = seededRandom(75705);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);
      final List<ApprovalRequest> first = rig.repository.listApprovals();
      final int sentBefore = rig.node.receivedCommands.length;
      rig.addApprovals(random);

      expect(rig.repository.listApprovals(), same(first));
      expect(rig.node.receivedCommands.length, sentBefore);
    }
  });

  test('${_prefix}_list_pending_approvals_property_keeps_order', () async {
    final Random random = seededRandom(75706);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);
      final List<ApprovalRequest> expected = <ApprovalRequest>[
        for (final ApprovalRequest approval in rig.repository.listApprovals())
          if (approval.isPending) approval,
      ];

      final List<ApprovalRequest> pending = rig.repository
          .listPendingApprovals();

      expect(pending, orderedEquals(expected));
      expect(
        listApprovalIdentifiers(pending),
        listPendingIdentifiers(rig.node),
      );
    }
  });

  test('${_prefix}_list_pending_approvals_property_is_frozen', () async {
    final Random random = seededRandom(75707);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);
      final List<ApprovalRequest> pending = rig.repository
          .listPendingApprovals();

      expect(
        () => pending.add(randomPendingApproval(random)),
        throwsUnsupportedError,
      );
    }
  });

  test(
    '${_prefix}_list_pending_approvals_property_agrees_with_fake',
    () async {
      final Random random = seededRandom(75708);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final ApprovalRig rig = await _buildLoadedRig(random);
        final FakeApprovalRepository fake = _buildTwinFake(random, rig);
        final int stepCount = random.nextInt(_longestSequence);

        for (int step = 0; step < stepCount; step += 1) {
          await _decideOnBoth(random, rig, fake);

          expect(
            listApprovalIdentifiers(rig.repository.listPendingApprovals()),
            listApprovalIdentifiers(fake.listPendingApprovals()),
          );
        }
      }
    },
  );

  test('${_prefix}_find_approval_property_finds_every_listed_one', () async {
    final Random random = seededRandom(75709);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);

      for (final ApprovalRequest listed in rig.repository.listApprovals()) {
        expect(rig.repository.findApproval(listed.id), same(listed));
      }
    }
  });

  test('${_prefix}_find_approval_property_unknown_names_the_id', () async {
    final Random random = seededRandom(75710);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);
      final String unknownId = 'unknown ${randomText(random)}';

      expect(
        () => rig.repository.findApproval(ApprovalId(unknownId)),
        throwsA(
          isA<RecordNotFound>().having(
            (RecordNotFound problem) => problem.identifier,
            'identifier',
            unknownId,
          ),
        ),
      );
    }
  });

  test('${_prefix}_find_approval_property_agrees_with_the_fake', () async {
    final Random random = seededRandom(75711);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);
      final FakeApprovalRepository fake = _buildTwinFake(random, rig);
      final String approvalId =
          random.nextBool() && rig.node.approvals.isNotEmpty
          ? pickOne(random, rig.node.approvals.keys.toList())
          : randomText(random);

      final bool isFoundByNode = _isFound(
        () => rig.repository.findApproval(ApprovalId(approvalId)),
      );
      final bool isFoundByFake = _isFound(
        () => fake.findApproval(ApprovalId(approvalId)),
      );

      expect(isFoundByNode, isFoundByFake);
      expect(isFoundByNode, rig.node.approvals.containsKey(approvalId));
    }
  });
}

bool _isFound(ApprovalRequest Function() find) {
  try {
    find();
  } on RecordNotFound {
    return false;
  }
  return true;
}
