import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_item_drafts.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';

import '../../support/random_inputs.dart';

FakeItemDraftRepository _buildRepository() {
  return FakeItemDraftRepository(
    drafts: buildGalleryItemDrafts(),
    drafterDeviceId: GalleryDeviceIds.officeServer,
    stepDelay: Duration.zero,
  );
}

ItemDraftRequest _requestFor(DraftKind kind, String wish) {
  return ItemDraftRequest(
    kind: kind,
    wish: wish,
    startedFrom: null,
    change: null,
  );
}

void main() {
  test(
    'test_draft_item_property_runs_then_finishes_the_prepared_draft',
    () async {
      final Random random = seededRandom(8301);
      final Map<DraftKind, ItemDraft> prepared = buildGalleryItemDrafts();

      for (int i = 0; i < propertyIterations; i += 1) {
        final DraftKind kind = pickOne(random, DraftKind.values);
        final ItemDraftRequest request = _requestFor(kind, 'Wish $i');

        final List<ItemDraftProgress> progress = await _buildRepository()
            .draftItem(request)
            .toList();

        expect(progress.first, isA<DraftRunning>());
        final DraftFinished finished = progress.last as DraftFinished;
        expect(
          finished.draft.item.runtimeType,
          prepared[kind]!.item.runtimeType,
        );
        expect(finished.draft.problems, isEmpty);
      }
    },
  );

  test('test_stop_drafting_property_a_stopped_draft_never_finishes', () async {
    final Random random = seededRandom(8302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeItemDraftRepository repository = _buildRepository();
      final ItemDraftRequest request = _requestFor(
        pickOne(random, DraftKind.values),
        'Wish $i',
      );
      final List<ItemDraftProgress> received = <ItemDraftProgress>[];
      final Future<void> streaming = repository
          .draftItem(request)
          .forEach(received.add);
      await Future<void>.delayed(Duration.zero);

      await repository.stopDrafting(request);
      await streaming;

      expect(received.whereType<DraftFinished>(), isEmpty);
      await expectLater(repository.stopDrafting(request), throwsStateError);
    }
  });

  test('blank wishes are refused', () async {
    await expectLater(
      _buildRepository().draftItem(_requestFor(DraftKind.task, '  ')).toList(),
      throwsArgumentError,
    );
  });
}
