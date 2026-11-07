import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import 'support/approval_inputs.dart';

const List<RunId> _runPool = <RunId>[
  RunId('run-a'),
  RunId('run-b'),
  RunId('run-c'),
  RunId(''),
  RunId('rün-ü'),
];
const int _largestApprovalCount = 8;

ApprovalRequest _approvalForRun(Random random, int index) {
  final ApprovalRequest base = randomApprovalWithId(random, 'approval-$index');
  return ApprovalRequest(
    id: base.id,
    runId: random.nextInt(4) == 0 ? null : pickOne(random, _runPool),
    action: base.action,
    requestedBy: base.requestedBy,
    requestedAt: base.requestedAt,
    decision: base.decision,
  );
}

List<ApprovalRequest> _randomApprovals(Random random) {
  final int count = random.nextInt(_largestApprovalCount);
  return <ApprovalRequest>[
    for (int index = 0; index < count; index += 1)
      _approvalForRun(random, index),
  ];
}

Set<RunId> _randomRunIds(Random random) {
  return <RunId>{
    for (final RunId runId in _runPool)
      if (random.nextBool()) runId,
  };
}

List<ApprovalId> _idsOf(List<ApprovalRequest> approvals) {
  return <ApprovalId>[
    for (final ApprovalRequest approval in approvals) approval.id,
  ];
}

void main() {
  test('test_forget_run_approvals_property_drops_exactly_the_approvals_of_'
      'the_removed_runs', () {
    final Random random = seededRandom(91301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ApprovalRequest> seeded = _randomApprovals(random);
      final FakeApprovalRepository repository = buildApprovalRepository(
        random,
        seeded,
      );
      final Set<RunId> removedRunIds = _randomRunIds(random);

      repository.forgetRunApprovals(removedRunIds);

      expect(_idsOf(repository.listApprovals()), <ApprovalId>[
        for (final ApprovalRequest approval in seeded)
          if (!removedRunIds.contains(approval.runId)) approval.id,
      ]);
    }
  });

  test('test_forget_run_approvals_property_keeps_approvals_without_a_run_'
      'and_keeps_kept_records_identical', () {
    final Random random = seededRandom(91302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ApprovalRequest> seeded = _randomApprovals(random);
      final FakeApprovalRepository repository = buildApprovalRepository(
        random,
        seeded,
      );

      repository.forgetRunApprovals(_runPool.toSet());

      final List<ApprovalRequest> kept = repository.listApprovals();
      expect(_idsOf(kept), <ApprovalId>[
        for (final ApprovalRequest approval in seeded)
          if (approval.runId == null) approval.id,
      ]);
      for (final ApprovalRequest approval in kept) {
        expect(seeded, contains(same(approval)));
      }
    }
  });

  test('test_forget_run_approvals_property_is_idempotent_and_an_empty_set_'
      'changes_nothing', () {
    final Random random = seededRandom(91303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ApprovalRequest> seeded = _randomApprovals(random);
      final FakeApprovalRepository repository = buildApprovalRepository(
        random,
        seeded,
      );
      final Set<RunId> removedRunIds = _randomRunIds(random);

      repository.forgetRunApprovals(<RunId>{});
      expect(_idsOf(repository.listApprovals()), _idsOf(seeded));
      repository.forgetRunApprovals(removedRunIds);
      final List<ApprovalId> once = _idsOf(repository.listApprovals());
      repository.forgetRunApprovals(removedRunIds);

      expect(_idsOf(repository.listApprovals()), once);
    }
  });
}
