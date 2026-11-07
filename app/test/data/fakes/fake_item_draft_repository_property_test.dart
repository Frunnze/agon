import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_item_drafts.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import 'support/item_draft_inputs.dart';

const List<String> _blankWishes = <String>[
  '',
  ' ',
  '\t\n',
  '\u{3000}',
  '\u{A0} \u{2003}',
];

void main() {
  test('test_fake_item_draft_repository_new_property_later_changes_to_the_'
      'seeds_do_not_leak', () async {
    final Random random = seededRandom(64801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<DraftKind, ItemDraft> drafts = buildGalleryItemDrafts();
      final FakeItemDraftRepository repository = buildItemDraftRepository(
        drafts,
        drafterDeviceId: DeviceId(randomText(random)),
      );
      final DraftKind kind = pickOne(random, DraftKind.values);
      final ItemDraft prepared = drafts[kind]!;
      drafts.clear();

      final List<ItemDraftProgress> progress = await draftItemToTheEnd(
        repository,
        randomItemDraftRequest(random, kind: kind),
      );

      expect((progress.last as DraftFinished).draft, same(prepared));
    }
  });

  test('test_fake_item_draft_repository_new_property_finishes_with_the_'
      'prepared_draft_of_that_kind', () async {
    final Random random = seededRandom(64802);
    final Map<DraftKind, ItemDraft> drafts = buildGalleryItemDrafts();
    final FakeItemDraftRepository repository = buildItemDraftRepository(
      drafts,
      drafterDeviceId: const DeviceId('drafter'),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, DraftKind.values);

      final List<ItemDraftProgress> progress = await draftItemToTheEnd(
        repository,
        randomItemDraftRequest(random, kind: kind),
      );

      expect((progress.last as DraftFinished).draft, same(drafts[kind]));
    }
  });

  test(
    'test_fake_item_draft_repository_new_property_running_names_the_drafter_'
    'device',
    () async {
      final Random random = seededRandom(64803);

      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceId drafterDeviceId = DeviceId(randomText(random));
        final FakeItemDraftRepository repository = buildItemDraftRepository(
          buildGalleryItemDrafts(),
          drafterDeviceId: drafterDeviceId,
        );

        final List<ItemDraftProgress> progress = await draftItemToTheEnd(
          repository,
          randomItemDraftRequest(
            random,
            kind: pickOne(random, DraftKind.values),
          ),
        );

        final DraftRunning running = progress.first as DraftRunning;
        expect(running.drafterDeviceId, drafterDeviceId);
        expect(AgentKind.values, contains(running.drafterKind));
      }
    },
  );

  test(
    'test_draft_item_property_blank_wishes_are_refused_before_any_progress',
    () async {
      final Random random = seededRandom(64804);
      final FakeItemDraftRepository repository = buildItemDraftRepository(
        buildGalleryItemDrafts(),
        drafterDeviceId: const DeviceId('drafter'),
      );

      for (int i = 0; i < propertyIterations; i += 1) {
        final ItemDraftRequest request = ItemDraftRequest(
          kind: pickOne(random, DraftKind.values),
          wish: pickOne(random, _blankWishes),
          startedFrom: null,
          change: null,
        );

        await expectLater(
          repository.draftItem(request),
          emitsError(isArgumentError),
        );
        await expectLater(repository.stopDrafting(request), throwsStateError);
      }
    },
  );

  test('test_draft_item_property_kinds_without_a_draft_are_refused', () async {
    final Random random = seededRandom(64805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftKind missing = pickOne(random, DraftKind.values);
      final Map<DraftKind, ItemDraft> drafts = buildGalleryItemDrafts();
      drafts.remove(missing);
      final FakeItemDraftRepository repository = buildItemDraftRepository(
        drafts,
        drafterDeviceId: const DeviceId('drafter'),
      );

      await expectLater(
        repository.draftItem(randomItemDraftRequest(random, kind: missing)),
        emitsError(isStateError),
      );
    }
  });

  test(
    'test_draft_item_property_running_comes_once_before_finished',
    () async {
      final Random random = seededRandom(64806);
      final FakeItemDraftRepository repository = buildItemDraftRepository(
        buildGalleryItemDrafts(),
        drafterDeviceId: const DeviceId('drafter'),
      );

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<ItemDraftProgress> progress = await draftItemToTheEnd(
          repository,
          randomItemDraftRequest(
            random,
            kind: pickOne(random, DraftKind.values),
          ),
        );

        expect(progress.length, 2);
        expect(progress.first, isA<DraftRunning>());
        expect(progress.last, isA<DraftFinished>());
      }
    },
  );

  test(
    'test_draft_item_property_the_same_running_request_is_refused',
    () async {
      final Random random = seededRandom(64807);
      final FakeItemDraftRepository repository = buildItemDraftRepository(
        buildGalleryItemDrafts(),
        drafterDeviceId: const DeviceId('drafter'),
      );

      for (int i = 0; i < propertyIterations; i += 1) {
        final ItemDraftRequest request = randomItemDraftRequest(
          random,
          kind: pickOne(random, DraftKind.values),
        );
        final Future<List<ItemDraftProgress>> first = draftItemToTheEnd(
          repository,
          request,
        );
        await Future<void>.delayed(Duration.zero);

        await expectLater(
          repository.draftItem(request),
          emitsError(isStateError),
        );
        expect((await first).last, isA<DraftFinished>());
      }
    },
  );
}
