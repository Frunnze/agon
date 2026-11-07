import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_approval_node.dart';
import 'support/refusals.dart';

const String _typePrefix = 'test_fake_approval_repository';
const String _thisDeviceText = 'this-device';
const int _sequenceIterations = 60;
const int _largestApprovalCount = 6;
const int _longestSequence = 8;

typedef _Pair = ({
  FakeApprovalRepository fake,
  NodeBackedApprovalRepository nodeBacked,
});

typedef _DecisionView = ({
  ApprovalId id,
  ApprovalDecision? decision,
  DeviceId? decidedBy,
});

Future<_Pair> _buildPair(Random random) async {
  final SimulatedApprovalNode simulated = SimulatedApprovalNode(
    thisDeviceId: _thisDeviceText,
  );
  final int count = random.nextInt(_largestApprovalCount);
  for (int i = 0; i < count; i += 1) {
    simulated.addApprovalFromElsewhere(random);
  }
  final NodeBackedApprovalRepository nodeBacked = NodeBackedApprovalRepository(
    channel: buildSimulatedChannel(simulated.answer),
  );
  await nodeBacked.load();
  final FakeApprovalRepository fake = FakeApprovalRepository(
    approvals: nodeBacked.listApprovals(),
    clock: FixedClock(randomUtcMoment(random)),
    currentDeviceId: const DeviceId(_thisDeviceText),
  );
  return (fake: fake, nodeBacked: nodeBacked);
}

ApprovalId _pickApprovalId(Random random, ApprovalRepository repository) {
  final List<ApprovalRequest> approvals = repository.listApprovals();
  if (approvals.isEmpty || random.nextInt(4) == 0) {
    return ApprovalId('approval-missing-${randomText(random)}');
  }
  return pickOne(random, approvals).id;
}

bool _isDecisionRefusal(Object error) {
  return error is StateError || error is RecordNotFound;
}

List<_DecisionView> _describeDecisions(List<ApprovalRequest> approvals) {
  final List<_DecisionView> views = <_DecisionView>[];
  for (final ApprovalRequest approval in approvals) {
    views.add((
      id: approval.id,
      decision: approval.decision?.decision,
      decidedBy: approval.decision?.decidedBy,
    ));
  }
  return views;
}

Future<void> _decideOnBoth(Random random, _Pair pair) async {
  final ApprovalId approvalId = _pickApprovalId(random, pair.fake);
  final ApprovalDecision decision = pickOne(random, ApprovalDecision.values);

  final bool isFakeRefused = await isRefused(
    () => pair.fake.decideApproval(approvalId, decision),
    isRefusal: _isDecisionRefusal,
  );
  final bool isNodeRefused = await isRefused(
    () => pair.nodeBacked.decideApproval(approvalId, decision),
    isRefusal: _isDecisionRefusal,
  );

  expect(isFakeRefused, isNodeRefused, reason: approvalId.value);
}

void main() {
  test('${_typePrefix}_decide_approval_property_agrees_with_the_node_'
      'backed_repository', () async {
    final Random random = seededRandom(63801);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await _decideOnBoth(random, pair);

        expect(
          _describeDecisions(pair.fake.listApprovals()),
          orderedEquals(_describeDecisions(pair.nodeBacked.listApprovals())),
        );
      }
    }
  });

  test('${_typePrefix}_list_pending_approvals_property_agrees_with_the_'
      'node_backed_repository', () async {
    final Random random = seededRandom(63802);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await _decideOnBoth(random, pair);
      }

      expect(
        _describeDecisions(pair.fake.listPendingApprovals()),
        orderedEquals(
          _describeDecisions(pair.nodeBacked.listPendingApprovals()),
        ),
      );
    }
  });

  test('${_typePrefix}_find_approval_property_agrees_with_the_node_'
      'backed_repository', () async {
    final Random random = seededRandom(63803);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await _decideOnBoth(random, pair);
      }

      for (final ApprovalRequest listed in pair.nodeBacked.listApprovals()) {
        final ApprovalRequest fromFake = pair.fake.findApproval(listed.id);
        final ApprovalRequest fromNode = pair.nodeBacked.findApproval(
          listed.id,
        );

        expect(
          _describeDecisions(<ApprovalRequest>[fromFake]),
          orderedEquals(_describeDecisions(<ApprovalRequest>[fromNode])),
        );
      }
    }
  });
}
