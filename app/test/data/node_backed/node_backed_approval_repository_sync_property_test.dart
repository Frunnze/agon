import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/approval_inputs.dart';
import '../fakes/support/refusals.dart';
import 'support/node_backed_approval_rig.dart';

const String _prefix = 'test_node_backed_approval_repository';
const int _sequenceIterations = 40;
const int _longestSequence = 6;
const node.ChangeTopic _approvalsChanged = node.AreaChanged(
  area: node.ChangeArea.approvals,
);

bool _refusesAsMissing(Object error) => error is RecordNotFound;

node.ChangeTopic _randomOtherTopic(Random random) {
  if (random.nextBool()) {
    return node.RunChanged(runId: RunId(randomText(random)));
  }
  final List<node.ChangeArea> otherAreas = <node.ChangeArea>[
    for (final node.ChangeArea area in node.ChangeArea.values)
      if (area != node.ChangeArea.approvals) area,
  ];
  return node.AreaChanged(area: pickOne(random, otherAreas));
}

Future<ApprovalRig> _buildLoadedRig(Random random) async {
  final ApprovalRig rig = ApprovalRig();
  rig.addApprovals(random);
  await rig.repository.load();
  return rig;
}

String _randomApprovalId(Random random, ApprovalRig rig) {
  if (rig.node.approvals.isEmpty || random.nextInt(4) == 0) {
    return 'approval-missing-${random.nextInt(1000)}';
  }
  return pickOne(random, rig.node.approvals.keys.toList());
}

Future<String> _describeOutcome(Future<ApprovalRequest> Function() decide) {
  final Future<String> decided = decide().then(
    (ApprovalRequest request) => 'decided ${request.decision?.decision}',
  );
  return decided.catchError(
    (Object error) => 'refused ${error.runtimeType}',
    test: (Object error) => error is StateError || error is RecordNotFound,
  );
}

void main() {
  test('${_prefix}_load_property_mirrors_the_node_after_additions', () async {
    final Random random = seededRandom(75801);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = ApprovalRig();
      final int loadCount = 1 + random.nextInt(_longestSequence);

      for (int load = 0; load < loadCount; load += 1) {
        rig.addApprovals(random);
        await rig.repository.load();

        expect(
          listApprovalIdentifiers(rig.repository.listApprovals()),
          rig.node.approvals.keys,
        );
      }
    }
  });

  test('${_prefix}_load_property_notifies_once_per_load', () async {
    final Random random = seededRandom(75802);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = ApprovalRig();
      final int loadCount = random.nextInt(_longestSequence);

      for (int load = 0; load < loadCount; load += 1) {
        rig.addApprovals(random);
        await rig.repository.load();
      }

      expect(rig.notifications.count, loadCount);
    }
  });

  test('${_prefix}_load_property_late_older_reply_loses', () async {
    final Random random = seededRandom(75803);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = ApprovalRig();
      final String approvalId = rig.node.addApprovalFromElsewhere(random);
      rig.node.approvals[approvalId]!['decision'] = null;
      await rig.repository.load();
      rig.transport.holdNextReply(listApprovalsCommand);

      final Future<void> olderLoad = rig.repository.load();
      await rig.transport.heldReplyArrival;
      await rig.repository.decideApproval(
        ApprovalId(approvalId),
        pickOne(random, ApprovalDecision.values),
      );
      rig.transport.releaseHeldReply();
      await olderLoad;

      expect(rig.repository.listPendingApprovals(), isEmpty);
      expect(
        rig.repository.findApproval(ApprovalId(approvalId)).isPending,
        false,
      );
    }
  });

  test('${_prefix}_apply_change_property_approvals_area_reloads', () async {
    final Random random = seededRandom(75804);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);
      final int notifiedBefore = rig.notifications.count;
      rig.addApprovals(random);

      await rig.repository.applyChange(_approvalsChanged);

      expect(
        listApprovalIdentifiers(rig.repository.listApprovals()),
        rig.node.approvals.keys,
      );
      expect(rig.notifications.count, notifiedBefore + 1);
    }
  });

  test('${_prefix}_apply_change_property_other_topics_do_nothing', () async {
    final Random random = seededRandom(75805);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);
      final List<ApprovalRequest> before = rig.repository.listApprovals();
      final int sentBefore = rig.node.receivedCommands.length;
      final int notifiedBefore = rig.notifications.count;
      rig.addApprovals(random);

      await rig.repository.applyChange(_randomOtherTopic(random));

      expect(rig.repository.listApprovals(), same(before));
      expect(rig.node.receivedCommands.length, sentBefore);
      expect(rig.notifications.count, notifiedBefore);
    }
  });

  test('${_prefix}_apply_change_property_refusal_keeps_the_list', () async {
    final Random random = seededRandom(75806);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);
      final List<ApprovalRequest> before = rig.repository.listApprovals();
      final int notifiedBefore = rig.notifications.count;
      rig.addApprovals(random);
      rig.listRefusal = 'the app server answered 503: ${randomText(random)}';

      await expectLater(
        rig.repository.applyChange(_approvalsChanged),
        throwsStateError,
      );

      expect(rig.repository.listApprovals(), same(before));
      expect(rig.notifications.count, notifiedBefore);
    }
  });

  test('${_prefix}_decide_approval_property_agrees_with_the_fake', () async {
    final Random random = seededRandom(75807);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);
      final FakeApprovalRepository fake = FakeApprovalRepository(
        approvals: rig.repository.listApprovals(),
        clock: FixedClock(randomUtcMoment(random)),
        currentDeviceId: approvalTestDevice,
      );
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        final ApprovalId approvalId = ApprovalId(
          _randomApprovalId(random, rig),
        );
        final ApprovalDecision decision = pickOne(
          random,
          ApprovalDecision.values,
        );

        final String nodeOutcome = await _describeOutcome(
          () => rig.repository.decideApproval(approvalId, decision),
        );
        final String fakeOutcome = await _describeOutcome(
          () => fake.decideApproval(approvalId, decision),
        );

        expect(nodeOutcome, fakeOutcome, reason: approvalId.value);
      }
      expect(
        listApprovalIdentifiers(rig.repository.listPendingApprovals()),
        listApprovalIdentifiers(fake.listPendingApprovals()),
      );
    }
  });

  test('${_prefix}_decide_approval_property_unknown_is_not_found', () async {
    final Random random = seededRandom(75808);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = await _buildLoadedRig(random);
      final List<ApprovalRequest> before = rig.repository.listApprovals();
      final ApprovalId unknownId = ApprovalId(
        'approval-missing-${random.nextInt(1000)}',
      );

      final bool isMissing = await isRefused(
        () => rig.repository.decideApproval(
          unknownId,
          pickOne(random, ApprovalDecision.values),
        ),
        isRefusal: _refusesAsMissing,
      );

      expect(isMissing, isTrue);
      expect(rig.repository.listApprovals(), same(before));
    }
  });

  test('${_prefix}_decide_approval_property_returns_the_decision', () async {
    final Random random = seededRandom(75809);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final ApprovalRig rig = ApprovalRig();
      rig.addApprovals(random);
      final String approvalId = rig.node.addApprovalFromElsewhere(random);
      rig.node.approvals[approvalId]!['decision'] = null;
      await rig.repository.load();
      final List<ApprovalRequest> before = rig.repository.listApprovals();
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );

      final ApprovalRequest decided = await rig.repository.decideApproval(
        ApprovalId(approvalId),
        decision,
      );

      expect(decided.decision?.decision, decision);
      expect(decided.decision?.decidedBy.value, rig.node.thisDeviceId);
      expect(rig.repository.findApproval(decided.id), same(decided));
      for (final ApprovalRequest other in before) {
        if (other.id == decided.id) {
          continue;
        }
        final ApprovalRequest after = rig.repository.findApproval(other.id);
        expect(after.isPending, other.isPending);
      }
    }
  });
}
