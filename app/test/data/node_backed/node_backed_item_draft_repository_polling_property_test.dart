import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/gated_item_draft_node.dart';
import 'support/item_draft_restarts.dart';

const int _pollingIterations = 40;

Future<DraftLog> _stopWhileAReplyIsHeld(
  GatedItemDraftNode node,
  NodeBackedItemDraftRepository repository,
  ItemDraftRequest request,
) async {
  final DraftLog stopped = listenToDraft(repository.draftItem(request));
  await waitUntil(() => node.heldPollCount > 0);
  await repository.stopDrafting(request);

  node.releaseHeldReplies();
  await stopped.done;
  return stopped;
}

void main() {
  test('test_poll_draft_property_a_late_done_reply_is_dropped', () async {
    final Random random = seededRandom(52801);

    for (int i = 0; i < _pollingIterations; i += 1) {
      final GatedItemDraftNode node = buildGatedNode(
        random,
        stoppedPolls: 0,
        restartedPolls: 0,
        heldReplyTiming: HeldReplyTiming.answeredWhenAsked,
      );
      final NodeBackedItemDraftRepository repository = buildDraftRepository(
        node,
      );

      final DraftLog stopped = await _stopWhileAReplyIsHeld(
        node,
        repository,
        randomDraftRequest(random),
      );

      expect(stopped.progress, isEmpty);
      expect(stopped.errors, isEmpty);
    }
  });

  test('test_poll_draft_property_a_late_error_reply_is_quiet', () async {
    final Random random = seededRandom(52802);

    for (int i = 0; i < _pollingIterations; i += 1) {
      final GatedItemDraftNode node = buildGatedNode(
        random,
        stoppedPolls: random.nextInt(3),
        restartedPolls: 0,
        heldReplyTiming: HeldReplyTiming.answeredWhenReleased,
      );
      final NodeBackedItemDraftRepository repository = buildDraftRepository(
        node,
      );

      final DraftLog stopped = await _stopWhileAReplyIsHeld(
        node,
        repository,
        randomDraftRequest(random),
      );

      expect(stopped.hasFinished, isFalse);
      expect(stopped.errors, isEmpty);
    }
  });

  test('test_poll_draft_property_reports_running_until_done', () async {
    final Random random = seededRandom(52803);

    for (int i = 0; i < _pollingIterations; i += 1) {
      final int polls = random.nextInt(5);
      final GatedItemDraftNode node = GatedItemDraftNode(
        random: random,
        pollsBeforeDoneByTask: <String, int>{gatedTaskId(1): polls},
        finishedStatus: randomDoneStatus(random),
        heldTaskId: null,
        heldReplyTiming: HeldReplyTiming.answeredWhenAsked,
      );
      final NodeBackedItemDraftRepository repository = buildDraftRepository(
        node,
      );

      final List<ItemDraftProgress> progress = await repository
          .draftItem(randomDraftRequest(random))
          .toList();

      expect(progress, hasLength(polls + 1));
      expect(progress.take(polls), everyElement(isA<DraftRunning>()));
      expect(progress.last, isA<DraftFinished>());
      expect(node.pollCountByTask[gatedTaskId(1)], polls + 1);
    }
  });

  test('test_is_still_running_property_other_requests_keep_running', () async {
    final Random random = seededRandom(52804);

    for (int i = 0; i < _pollingIterations; i += 1) {
      final GatedItemDraftNode node = buildGatedNode(
        random,
        stoppedPolls: pollsOfALongDraft,
        restartedPolls: random.nextInt(4),
        heldReplyTiming: HeldReplyTiming.answeredWhenAsked,
      );
      final NodeBackedItemDraftRepository repository = buildDraftRepository(
        node,
      );
      final ItemDraftRequest stoppedRequest = randomDraftRequest(random);
      final ItemDraftRequest keptRequest = ItemDraftRequest(
        kind: stoppedRequest.kind,
        wish: '${stoppedRequest.wish} kept',
        startedFrom: stoppedRequest.startedFrom,
        change: null,
      );
      final DraftLog stopped = listenToDraft(
        repository.draftItem(stoppedRequest),
      );
      await waitUntil(() => node.heldPollCount > 0);
      final DraftLog kept = listenToDraft(repository.draftItem(keptRequest));
      await waitUntil(() => node.draftCount == 2);

      await repository.stopDrafting(stoppedRequest);
      node.releaseHeldReplies();
      await stopped.done;
      await kept.done;

      expect(stopped.progress, isEmpty);
      expect(kept.progress.last, isA<DraftFinished>());
    }
  });

  test(
    'test_is_still_running_property_a_third_draft_after_restart_works',
    () async {
      final Random random = seededRandom(52805);

      for (int i = 0; i < _pollingIterations; i += 1) {
        final GatedItemDraftNode node = buildGatedNode(
          random,
          stoppedPolls: random.nextBool() ? 0 : pollsOfALongDraft,
          restartedPolls: random.nextInt(3),
          heldReplyTiming: pickOne(random, HeldReplyTiming.values),
        );
        final NodeBackedItemDraftRepository repository = buildDraftRepository(
          node,
        );
        final ItemDraftRequest request = randomDraftRequest(random);
        final StopAndRestart drafts = await stopThenDraftAgain(
          node,
          repository,
          request,
        );
        await drafts.restarted.done;

        final List<ItemDraftProgress> third = await repository
            .draftItem(request)
            .toList();

        expect(third.last, isA<DraftFinished>());
        expect(node.draftCount, 3);
      }
    },
  );

  test(
    'test_is_still_running_property_finished_drafts_free_the_request',
    () async {
      final Random random = seededRandom(52806);

      for (int i = 0; i < _pollingIterations; i += 1) {
        final int rounds = 1 + random.nextInt(3);
        final GatedItemDraftNode node = GatedItemDraftNode(
          random: random,
          pollsBeforeDoneByTask: const <String, int>{},
          finishedStatus: randomDoneStatus(random),
          heldTaskId: null,
          heldReplyTiming: HeldReplyTiming.answeredWhenAsked,
        );
        final NodeBackedItemDraftRepository repository = buildDraftRepository(
          node,
        );
        final ItemDraftRequest request = randomDraftRequest(random);

        for (int round = 0; round < rounds; round += 1) {
          final List<ItemDraftProgress> progress = await repository
              .draftItem(request)
              .toList();
          expect(progress.single, isA<DraftFinished>());
        }

        await expectLater(repository.stopDrafting(request), throwsStateError);
        expect(node.draftCount, rounds);
      }
    },
  );
}
