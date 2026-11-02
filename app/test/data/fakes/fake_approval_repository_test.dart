import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';

FakeApprovalRepository buildGalleryApprovalRepository() {
  return FakeApprovalRepository(
    approvals: galleryApprovals,
    clock: FixedClock(galleryNow),
    currentDeviceId: GalleryDeviceIds.airLaptop,
  );
}

void main() {
  test('test_list_approvals_property_count_never_changes', () async {
    final Random random = seededRandom(401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeApprovalRepository repository =
          buildGalleryApprovalRepository();
      final ApprovalRequest request = pickOne(random, galleryApprovals);
      await repository.decideApproval(
        request.id,
        pickOne(random, ApprovalDecision.values),
      );

      expect(repository.listApprovals().length, galleryApprovals.length);
    }
  });

  test(
    'test_list_pending_approvals_property_shrinks_by_one_per_decision',
    () async {
      final Random random = seededRandom(402);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeApprovalRepository repository =
            buildGalleryApprovalRepository();
        final List<ApprovalRequest> shuffled = <ApprovalRequest>[
          ...galleryApprovals,
        ]..shuffle(random);
        int expectedPending = galleryApprovals.length;

        for (final ApprovalRequest request in shuffled) {
          await repository.decideApproval(
            request.id,
            pickOne(random, ApprovalDecision.values),
          );
          expectedPending -= 1;
          expect(repository.listPendingApprovals().length, expectedPending);
        }
      }
    },
  );

  test('test_find_approval_property_returns_requested_id', () {
    final Random random = seededRandom(403);
    final FakeApprovalRepository repository = buildGalleryApprovalRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRequest request = pickOne(random, galleryApprovals);
      expect(repository.findApproval(request.id).id, request.id);
    }
    expect(
      () => repository.findApproval(const ApprovalId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('test_decide_approval_property_signed_once_by_this_device', () async {
    final Random random = seededRandom(404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeApprovalRepository repository =
          buildGalleryApprovalRepository();
      final ApprovalRequest request = pickOne(random, galleryApprovals);
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final ApprovalRequest decided = await repository.decideApproval(
        request.id,
        decision,
      );

      expect(decided.decision?.decision, decision);
      expect(decided.decision?.decidedBy, GalleryDeviceIds.airLaptop);
      await expectLater(
        repository.decideApproval(request.id, decision),
        throwsA(isA<StateError>()),
      );
    }
  });
}
