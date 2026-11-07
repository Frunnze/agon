import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/approval_inputs.dart';

const String _typePrefix = 'test_fake_approval_repository';
const String _approvalKind = 'approval request';

void main() {
  test('${_typePrefix}_find_approval_property_returns_the_current_'
      'record', () async {
    final Random random = seededRandom(63708);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeApprovalRepository repository = buildApprovalRepository(
        random,
        randomApprovals(random),
      );
      await decideRandomPendingApprovals(random, repository);

      for (final ApprovalRequest listed in repository.listApprovals()) {
        final ApprovalRequest found = repository.findApproval(listed.id);

        expect(identical(found, listed), isTrue);
      }
    }
  });

  test('${_typePrefix}_find_approval_property_unknown_id_names_the_id', () {
    final Random random = seededRandom(63709);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ApprovalRequest> seeded = randomApprovals(random);
      final FakeApprovalRepository repository = buildApprovalRepository(
        random,
        seeded,
      );
      final String unknownText = 'unknown ${randomText(random)}';

      expect(
        () => repository.findApproval(ApprovalId(unknownText)),
        throwsA(
          isA<RecordNotFound>()
              .having((RecordNotFound e) => e.kind, 'kind', _approvalKind)
              .having(
                (RecordNotFound e) => e.identifier,
                'identifier',
                unknownText,
              ),
        ),
      );
    }
  });

  test('${_typePrefix}_decide_approval_property_signs_with_this_device_'
      'at_the_clock_moment', () async {
    final Random random = seededRandom(63710);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRequest pending = randomPendingApproval(random);
      final CountedApprovals counted = buildCountedApprovals(
        random,
        <ApprovalRequest>[...randomApprovals(random), pending],
      );
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );

      final ApprovalRequest decided = await counted.repository.decideApproval(
        pending.id,
        decision,
      );

      final ApprovalRequest stored = counted.repository.findApproval(
        pending.id,
      );
      expect(decided.decision?.decision, decision);
      expect(decided.decision?.decidedBy, approvalTestDevice);
      expect(decided.decision?.decidedAt, counted.moment);
      expect(decided.id, pending.id);
      expect(decided.runId, pending.runId);
      expect(identical(decided.action, pending.action), isTrue);
      expect(decided.requestedBy, pending.requestedBy);
      expect(decided.requestedAt, pending.requestedAt);
      expect(identical(stored, decided), isTrue);
      expect(counted.notifications.count, 1);
    }
  });

  test('${_typePrefix}_decide_approval_property_refusals_change_'
      'nothing', () async {
    final Random random = seededRandom(63711);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedApprovals counted = buildCountedApprovals(
        random,
        randomApprovals(random),
      );
      await decideRandomPendingApprovals(random, counted.repository);
      final List<ApprovalRequest> before = counted.repository.listApprovals();
      final int notificationsBefore = counted.notifications.count;
      final List<ApprovalRequest> decided = <ApprovalRequest>[];
      for (final ApprovalRequest approval in before) {
        if (!approval.isPending) {
          decided.add(approval);
        }
      }
      final bool decidesTwice = decided.isNotEmpty && random.nextBool();
      final ApprovalId refusedId = decidesTwice
          ? pickOne(random, decided).id
          : ApprovalId('missing ${randomText(random)}');

      await expectLater(
        counted.repository.decideApproval(
          refusedId,
          pickOne(random, ApprovalDecision.values),
        ),
        throwsA(decidesTwice ? isStateError : isA<RecordNotFound>()),
      );

      expect(identical(counted.repository.listApprovals(), before), isTrue);
      expect(counted.notifications.count, notificationsBefore);
    }
  });
}
