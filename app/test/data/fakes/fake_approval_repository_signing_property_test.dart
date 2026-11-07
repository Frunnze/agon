import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/approval_inputs.dart';
import 'support/workflow_usage_checks.dart';
import 'support/workflow_usage_inputs.dart';

typedef _SigningSeed = ({
  FakeApprovalRepository repository,
  List<ApprovalRequest> approvals,
  WorkflowId forgotten,
});

_SigningSeed _seedSigning(Random random) {
  final List<ApprovalRequest> approvals = randomApprovalsSigning(
    random,
    sampleWorkflowIds,
  );
  final List<WorkflowId> candidates = <WorkflowId>[
    ...sampleWorkflowIds,
    unlistedWorkflowId,
    WorkflowId(randomText(random)),
  ];
  return (
    repository: buildApprovalRepository(random, approvals),
    approvals: approvals,
    forgotten: pickOne(random, candidates),
  );
}

List<ApprovalRequest> _listForgotten(_SigningSeed seed) {
  final Set<WorkflowId> forgotten = <WorkflowId>{seed.forgotten};
  return <ApprovalRequest>[
    for (final ApprovalRequest approval in seed.approvals)
      if (asksToSignAny(approval, forgotten)) approval,
  ];
}

void main() {
  test('test_forget_signing_requests_property_removes_exactly_the_'
      'signing_ones', () {
    final Random random = seededRandom(95151);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SigningSeed seed = _seedSigning(random);

      seed.repository.forgetSigningRequests(seed.forgotten);

      final List<ApprovalRequest> expected = keepApprovalsSigningNone(
        seed.approvals,
        <WorkflowId>{seed.forgotten},
      );
      expect(seed.repository.listApprovals(), orderedEquals(expected));
    }
  });

  test('test_forget_signing_requests_property_is_idempotent', () {
    final Random random = seededRandom(95152);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SigningSeed seed = _seedSigning(random);

      seed.repository.forgetSigningRequests(seed.forgotten);
      final List<ApprovalRequest> once = seed.repository.listApprovals();
      seed.repository.forgetSigningRequests(seed.forgotten);

      expect(seed.repository.listApprovals(), orderedEquals(once));
    }
  });

  test('test_forget_signing_requests_property_keeps_decisions_and_'
      'pending_view', () async {
    final Random random = seededRandom(95153);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SigningSeed seed = _seedSigning(random);
      await decideRandomPendingApprovals(random, seed.repository);
      final List<ApprovalRequest> decided = seed.repository.listApprovals();

      seed.repository.forgetSigningRequests(seed.forgotten);

      final List<ApprovalRequest> listed = seed.repository.listApprovals();
      expect(
        listed,
        orderedEquals(
          keepApprovalsSigningNone(decided, <WorkflowId>{seed.forgotten}),
        ),
      );
      expect(
        seed.repository.listPendingApprovals(),
        orderedEquals(<ApprovalRequest>[
          for (final ApprovalRequest approval in listed)
            if (approval.isPending) approval,
        ]),
      );
    }
  });

  test('test_forget_signing_requests_property_forgotten_cannot_be_'
      'found_or_decided', () async {
    final Random random = seededRandom(95154);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SigningSeed seed = _seedSigning(random);

      seed.repository.forgetSigningRequests(seed.forgotten);

      for (final ApprovalRequest approval in _listForgotten(seed)) {
        expect(
          () => seed.repository.findApproval(approval.id),
          throwsA(isA<RecordNotFound>()),
        );
        await expectLater(
          seed.repository.decideApproval(
            approval.id,
            pickOne(random, ApprovalDecision.values),
          ),
          throwsA(isA<RecordNotFound>()),
        );
      }
    }
  });

  test('test_forget_signing_requests_property_listing_cannot_be_'
      'changed', () {
    final Random random = seededRandom(95155);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SigningSeed seed = _seedSigning(random);

      seed.repository.forgetSigningRequests(seed.forgotten);

      final List<ApprovalRequest> listed = seed.repository.listApprovals();
      expect(
        () => listed.add(randomListedApproval(random)),
        throwsUnsupportedError,
      );
      expect(listed.clear, throwsUnsupportedError);
    }
  });
}
