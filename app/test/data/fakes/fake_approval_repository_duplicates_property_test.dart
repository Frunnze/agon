import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';

import '../../support/random_inputs.dart';
import 'support/approval_inputs.dart';

const String _typePrefix = 'test_fake_approval_repository';

List<ApprovalRequest> _withDuplicate(
  Random random,
  List<ApprovalRequest> approvals,
) {
  final ApprovalRequest original = pickOne(random, approvals);
  final List<ApprovalRequest> duplicated = List<ApprovalRequest>.of(approvals);
  final ApprovalRequest copy = randomApprovalWithId(random, original.id.value);
  duplicated.insert(random.nextInt(duplicated.length + 1), copy);
  return duplicated;
}

void main() {
  test('${_typePrefix}_constructor_property_refuses_duplicate_approval_'
      'ids', () {
    final Random random = seededRandom(66301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ApprovalRequest> approvals = randomApprovals(random);
      if (approvals.isEmpty) {
        continue;
      }
      final List<ApprovalRequest> duplicated = _withDuplicate(
        random,
        approvals,
      );

      expect(
        () => buildApprovalRepository(random, duplicated),
        throwsArgumentError,
      );
    }
  });

  test('${_typePrefix}_constructor_property_names_the_duplicate_'
      'approval', () {
    final Random random = seededRandom(66302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String identifier = randomText(random);
      final List<ApprovalRequest> duplicated = <ApprovalRequest>[
        randomApprovalWithId(random, identifier),
        randomApprovalWithId(random, identifier),
      ];

      expect(
        () => buildApprovalRepository(random, duplicated),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.invalidValue,
            'invalidValue',
            identifier,
          ),
        ),
      );
    }
  });

  test('${_typePrefix}_constructor_property_unique_ids_in_any_order_are_'
      'kept', () async {
    final Random random = seededRandom(66303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ApprovalRequest> approvals = randomApprovals(random);
      approvals.shuffle(random);

      final FakeApprovalRepository repository = buildApprovalRepository(
        random,
        approvals,
      );
      await decideRandomPendingApprovals(random, repository);

      expect(repository.listApprovals(), hasLength(approvals.length));
      for (final ApprovalRequest approval in approvals) {
        expect(repository.findApproval(approval.id).id, approval.id);
      }
    }
  });
}
