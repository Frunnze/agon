import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_approval_node.dart';
import 'support/simulated_work_node.dart';

const int _sequenceIterations = 25;
const int _stepsPerSequence = 10;

typedef _Fixture = ({
  SimulatedApprovalNode node,
  NodeBackedApprovalRepository repository,
});

_Fixture _buildFixture() {
  final SimulatedApprovalNode simulated = SimulatedApprovalNode(
    thisDeviceId: 'me',
  );
  final NodeBackedApprovalRepository repository = NodeBackedApprovalRepository(
    channel: buildSimulatedChannel(simulated.answer),
  );
  return (node: simulated, repository: repository);
}

void _expectMirrorsNode(_Fixture fixture) {
  final List<ApprovalRequest> approvals = fixture.repository.listApprovals();
  expect(
    approvals.map((ApprovalRequest request) => request.id.value),
    fixture.node.approvals.keys,
  );
  for (final ApprovalRequest request in approvals) {
    final WireRecord wire = fixture.node.approvals[request.id.value]!;
    expect(request.isPending, wire['decision'] == null);
  }

  final List<ApprovalRequest> pending = fixture.repository
      .listPendingApprovals();
  expect(
    pending.every((ApprovalRequest request) => request.isPending),
    isTrue,
  );
  expect(
    pending.length,
    approvals.where((ApprovalRequest request) => request.isPending).length,
  );
}

void main() {
  test('test_apply_change_property_approvals_mirror_the_node', () async {
    final Random random = seededRandom(9931);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      await fixture.repository.load();

      for (int step = 0; step < _stepsPerSequence; step += 1) {
        final List<ApprovalRequest> pending = fixture.repository
            .listPendingApprovals();
        if (pending.isNotEmpty && random.nextBool()) {
          await fixture.repository.decideApproval(
            pickOne(random, pending).id,
            pickOne(random, ApprovalDecision.values),
          );
        } else {
          fixture.node.addApprovalFromElsewhere(random);
          await fixture.repository.applyChange(
            const node.AreaChanged(area: node.ChangeArea.approvals),
          );
        }
        _expectMirrorsNode(fixture);
      }
    }
  });

  test('test_decide_approval_property_decision_is_recorded', () async {
    final Random random = seededRandom(9932);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final String approvalId = fixture.node.addApprovalFromElsewhere(random);
      fixture.node.approvals[approvalId]!['decision'] = null;
      await fixture.repository.load();
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );

      final ApprovalRequest decided = await fixture.repository.decideApproval(
        ApprovalId(approvalId),
        decision,
      );

      expect(decided.isPending, isFalse);
      expect(decided.decision!.decision, decision);
      expect(
        fixture.repository.listPendingApprovals().map(
          (ApprovalRequest request) => request.id,
        ),
        isNot(contains(decided.id)),
      );
    }
  });

  test('test_decide_approval_property_second_decision_is_refused', () async {
    final Random random = seededRandom(9933);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final String approvalId = fixture.node.addApprovalFromElsewhere(random);
      fixture.node.approvals[approvalId]!['decision'] = null;
      await fixture.repository.load();
      await fixture.repository.decideApproval(
        ApprovalId(approvalId),
        ApprovalDecision.approved,
      );

      await expectLater(
        fixture.repository.decideApproval(
          ApprovalId(approvalId),
          ApprovalDecision.denied,
        ),
        throwsStateError,
      );
    }
  });

  test('test_apply_change_property_other_areas_send_nothing', () async {
    final _Fixture fixture = _buildFixture();
    for (final node.ChangeArea area in node.ChangeArea.values) {
      if (area == node.ChangeArea.approvals) {
        continue;
      }
      await fixture.repository.applyChange(node.AreaChanged(area: area));
    }
    expect(fixture.node.receivedCommands, isEmpty);
  });

  test('test_find_approval_property_unknown_is_record_not_found', () {
    final Random random = seededRandom(9934);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < propertyIterations; i += 1) {
      expect(
        () => fixture.repository.findApproval(ApprovalId(randomText(random))),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
