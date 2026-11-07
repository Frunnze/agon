import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_item_drafts.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';

import '../../support/random_inputs.dart';
import 'support/item_draft_inputs.dart';

final class _StopWhenRunning {
  _StopWhenRunning({required this.repository, required this.request});

  final FakeItemDraftRepository repository;
  final ItemDraftRequest request;
  final List<ItemDraftProgress> received = <ItemDraftProgress>[];

  void receive(ItemDraftProgress progress) {
    received.add(progress);
    if (progress is DraftRunning) {
      unawaited(repository.stopDrafting(request));
    }
  }
}

void main() {
  test('test_draft_item_property_a_stopped_request_drafted_again_finishes_'
      'once', () async {
    final Random random = seededRandom(64808);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeItemDraftRepository repository = buildItemDraftRepository(
        buildGalleryItemDrafts(),
        drafterDeviceId: const DeviceId('drafter'),
      );
      final ItemDraftRequest request = randomItemDraftRequest(
        random,
        kind: pickOne(random, DraftKind.values),
      );
      final Future<List<ItemDraftProgress>> stopped = draftItemToTheEnd(
        repository,
        request,
      );
      await Future<void>.delayed(Duration.zero);
      await repository.stopDrafting(request);

      final List<ItemDraftProgress> again = await draftItemToTheEnd(
        repository,
        request,
      );

      expect(await stopped, isEmpty);
      expect(again.length, 2);
      expect(again.last, isA<DraftFinished>());
    }
  });

  test('test_stop_drafting_property_idle_requests_are_refused', () async {
    final Random random = seededRandom(64809);
    final FakeItemDraftRepository repository = buildItemDraftRepository(
      buildGalleryItemDrafts(),
      drafterDeviceId: const DeviceId('drafter'),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final ItemDraftRequest request = randomItemDraftRequest(
        random,
        kind: pickOne(random, DraftKind.values),
      );
      repository.draftItem(request);

      await expectLater(repository.stopDrafting(request), throwsStateError);
    }
  });

  test('test_stop_drafting_property_stopping_while_running_never_'
      'finishes', () async {
    final Random random = seededRandom(64810);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeItemDraftRepository repository = buildItemDraftRepository(
        buildGalleryItemDrafts(),
        drafterDeviceId: const DeviceId('drafter'),
      );
      final ItemDraftRequest request = randomItemDraftRequest(
        random,
        kind: pickOne(random, DraftKind.values),
      );
      final _StopWhenRunning log = _StopWhenRunning(
        repository: repository,
        request: request,
      );

      await repository.draftItem(request).forEach(log.receive);

      expect(log.received.length, 1);
      expect(log.received.single, isA<DraftRunning>());
      await expectLater(repository.stopDrafting(request), throwsStateError);
    }
  });

  test('test_stop_drafting_property_other_requests_keep_running', () async {
    final Random random = seededRandom(64811);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeItemDraftRepository repository = buildItemDraftRepository(
        buildGalleryItemDrafts(),
        drafterDeviceId: const DeviceId('drafter'),
      );
      final DraftKind kind = pickOne(random, DraftKind.values);
      final ItemDraftRequest stoppedRequest = randomItemDraftRequest(
        random,
        kind: kind,
      );
      final ItemDraftRequest keptRequest = randomItemDraftRequest(
        random,
        kind: kind,
      );
      final Future<List<ItemDraftProgress>> stopped = draftItemToTheEnd(
        repository,
        stoppedRequest,
      );
      final Future<List<ItemDraftProgress>> kept = draftItemToTheEnd(
        repository,
        keptRequest,
      );
      await Future<void>.delayed(Duration.zero);

      await repository.stopDrafting(stoppedRequest);

      expect(await stopped, isEmpty);
      expect((await kept).last, isA<DraftFinished>());
    }
  });

  test('test_stop_drafting_property_a_finished_draft_cannot_be_'
      'stopped', () async {
    final Random random = seededRandom(64812);
    final FakeItemDraftRepository repository = buildItemDraftRepository(
      buildGalleryItemDrafts(),
      drafterDeviceId: const DeviceId('drafter'),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final ItemDraftRequest request = randomItemDraftRequest(
        random,
        kind: pickOne(random, DraftKind.values),
      );
      await draftItemToTheEnd(repository, request);

      await expectLater(repository.stopDrafting(request), throwsStateError);
    }
  });

  test('test_is_still_running_property_a_restarted_request_owns_its_'
      'run', () async {
    final Random random = seededRandom(64813);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeItemDraftRepository repository = buildItemDraftRepository(
        buildGalleryItemDrafts(),
        drafterDeviceId: const DeviceId('drafter'),
      );
      final ItemDraftRequest request = randomItemDraftRequest(
        random,
        kind: pickOne(random, DraftKind.values),
      );
      final Future<List<ItemDraftProgress>> first = draftItemToTheEnd(
        repository,
        request,
      );
      await Future<void>.delayed(Duration.zero);
      await repository.stopDrafting(request);
      final Future<List<ItemDraftProgress>> second = draftItemToTheEnd(
        repository,
        request,
      );
      await Future<void>.delayed(Duration.zero);
      await first;

      await repository.stopDrafting(request);

      expect(await second, isEmpty);
    }
  });

  test('test_is_still_running_property_a_finished_run_frees_the_'
      'request', () async {
    final Random random = seededRandom(64814);
    final FakeItemDraftRepository repository = buildItemDraftRepository(
      buildGalleryItemDrafts(),
      drafterDeviceId: const DeviceId('drafter'),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final ItemDraftRequest request = randomItemDraftRequest(
        random,
        kind: pickOne(random, DraftKind.values),
      );
      final int roundCount = 1 + random.nextInt(3);

      for (int round = 0; round < roundCount; round += 1) {
        final List<ItemDraftProgress> progress = await draftItemToTheEnd(
          repository,
          request,
        );
        expect(progress.last, isA<DraftFinished>());
      }
    }
  });

  test('test_is_still_running_property_a_second_stop_is_refused', () async {
    final Random random = seededRandom(64815);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeItemDraftRepository repository = buildItemDraftRepository(
        buildGalleryItemDrafts(),
        drafterDeviceId: const DeviceId('drafter'),
      );
      final ItemDraftRequest request = randomItemDraftRequest(
        random,
        kind: pickOne(random, DraftKind.values),
      );
      final Future<List<ItemDraftProgress>> stopped = draftItemToTheEnd(
        repository,
        request,
      );
      await Future<void>.delayed(Duration.zero);

      await repository.stopDrafting(request);

      await expectLater(repository.stopDrafting(request), throwsStateError);
      expect(await stopped, isEmpty);
    }
  });
}
