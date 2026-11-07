import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../bridge/support/list_copy_properties.dart';
import '../../support/random_inputs.dart';
import 'support/approval_inputs.dart';

const String _typePrefix = 'test_fake_approval_repository';

List<ApprovalRequest> _readApprovals(FakeApprovalRepository repository) {
  return repository.listApprovals();
}

List<ApprovalId> _listIdentifiers(List<ApprovalRequest> approvals) {
  final List<ApprovalId> identifiers = <ApprovalId>[];
  for (final ApprovalRequest approval in approvals) {
    identifiers.add(approval.id);
  }
  return identifiers;
}

void main() {
  testListCopyProperties(
    const ListCopy<FakeApprovalRepository, ApprovalRequest>(
      testNamePrefix: '${_typePrefix}_constructor_property_approvals',
      seed: 63701,
      buildElement: randomListedApproval,
      construct: buildApprovalRepository,
      readList: _readApprovals,
    ),
  );

  test('${_typePrefix}_list_approvals_property_keeps_order_and_'
      'undecided_records', () async {
    final Random random = seededRandom(63704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ApprovalRequest> seeded = randomApprovals(random);
      final FakeApprovalRepository repository = buildApprovalRepository(
        random,
        seeded,
      );

      await decideRandomPendingApprovals(random, repository);

      final List<ApprovalRequest> listed = repository.listApprovals();
      expect(
        _listIdentifiers(listed),
        orderedEquals(_listIdentifiers(seeded)),
      );
      for (int index = 0; index < seeded.length; index += 1) {
        if (listed[index].isPending || !seeded[index].isPending) {
          expect(identical(listed[index], seeded[index]), isTrue);
        }
      }
    }
  });

  test('${_typePrefix}_list_approvals_property_cannot_be_changed', () async {
    final Random random = seededRandom(63705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeApprovalRepository repository = buildApprovalRepository(
        random,
        randomApprovals(random),
      );
      await decideRandomPendingApprovals(random, repository);
      final List<ApprovalRequest> listed = repository.listApprovals();
      final ApprovalRequest extra = randomListedApproval(random);

      expect(() => listed.add(extra), throwsUnsupportedError);
      expect(listed.clear, throwsUnsupportedError);
    }
  });

  test('${_typePrefix}_list_pending_approvals_property_is_the_undecided_'
      'approvals_in_order', () async {
    final Random random = seededRandom(63706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeApprovalRepository repository = buildApprovalRepository(
        random,
        randomApprovals(random),
      );
      await decideRandomPendingApprovals(random, repository);
      final List<ApprovalRequest> expected = <ApprovalRequest>[];
      for (final ApprovalRequest approval in repository.listApprovals()) {
        if (approval.decision == null) {
          expected.add(approval);
        }
      }

      final List<ApprovalRequest> pending = repository.listPendingApprovals();

      expect(pending, orderedEquals(expected));
    }
  });

  test('${_typePrefix}_list_pending_approvals_property_cannot_be_'
      'changed', () async {
    final Random random = seededRandom(63707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeApprovalRepository repository = buildApprovalRepository(
        random,
        randomApprovals(random),
      );
      await decideRandomPendingApprovals(random, repository);
      final List<ApprovalRequest> pending = repository.listPendingApprovals();
      final ApprovalRequest extra = randomListedApproval(random);

      expect(() => pending.add(extra), throwsUnsupportedError);
      expect(pending.clear, throwsUnsupportedError);
    }
  });
}
