import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/gated_item_draft_node.dart';
import 'support/item_draft_restarts.dart';

const int _restartIterations = 40;

HeldReplyTiming _randomTiming(Random random) {
  return pickOne(random, HeldReplyTiming.values);
}

void main() {
  test('test_draft_item_property_a_stopped_request_drafted_again_finishes_'
      'once', () async {
    final Random random = seededRandom(52701);

    for (int i = 0; i < _restartIterations; i += 1) {
      final int restartedPolls = random.nextInt(4);
      final GatedItemDraftNode node = buildGatedNode(
        random,
        stoppedPolls: random.nextBool() ? 0 : pollsOfALongDraft,
        restartedPolls: restartedPolls,
        heldReplyTiming: _randomTiming(random),
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

      expect(drafts.stopped.hasFinished, isFalse);
      expect(drafts.stopped.errors, isEmpty);
      expect(drafts.restarted.errors, isEmpty);
      expect(drafts.restarted.progress.last, isA<DraftFinished>());
      expect(
        drafts.restarted.progress.whereType<DraftRunning>(),
        hasLength(restartedPolls),
      );
    }
  });

  test('test_draft_item_property_a_running_request_is_drafted_once', () async {
    final Random random = seededRandom(52702);

    for (int i = 0; i < _restartIterations; i += 1) {
      final GatedItemDraftNode node = buildGatedNode(
        random,
        stoppedPolls: pollsOfALongDraft,
        restartedPolls: 0,
        heldReplyTiming: _randomTiming(random),
      );
      final NodeBackedItemDraftRepository repository = buildDraftRepository(
        node,
      );
      final ItemDraftRequest request = randomDraftRequest(random);
      final DraftLog running = listenToDraft(repository.draftItem(request));
      await waitUntil(() => node.heldPollCount > 0);

      await expectLater(
        repository.draftItem(request).toList(),
        throwsStateError,
      );

      await repository.stopDrafting(request);
      node.releaseHeldReplies();
      await running.done;
      expect(node.draftCount, 1);
      expect(running.errors, isEmpty);
    }
  });

  test('test_draft_item_property_each_run_polls_only_its_own_task', () async {
    final Random random = seededRandom(52703);

    for (int i = 0; i < _restartIterations; i += 1) {
      final GatedItemDraftNode node = buildGatedNode(
        random,
        stoppedPolls: pollsOfALongDraft,
        restartedPolls: random.nextInt(4),
        heldReplyTiming: HeldReplyTiming.answeredWhenAsked,
      );
      final NodeBackedItemDraftRepository repository = buildDraftRepository(
        node,
      );
      final ItemDraftRequest request = randomDraftRequest(random);
      final DraftLog stopped = listenToDraft(repository.draftItem(request));
      await waitUntil(() => node.heldPollCount > 0);
      await repository.stopDrafting(request);
      final int pollsAtStop = node.pollCountByTask[gatedTaskId(1)]!;

      final DraftLog restarted = listenToDraft(repository.draftItem(request));
      await waitUntil(() => node.draftCount == 2);
      node.releaseHeldReplies();
      await stopped.done;
      await restarted.done;

      expect(node.pollCountByTask[gatedTaskId(1)], pollsAtStop);
      expect(node.pollCountByTask[gatedTaskId(2)], isPositive);
      expect(node.draftCount, 2);
    }
  });

  test(
    'test_stop_drafting_property_a_restarted_request_can_be_stopped',
    () async {
      final Random random = seededRandom(52704);

      for (int i = 0; i < _restartIterations; i += 1) {
        final GatedItemDraftNode node = buildGatedNode(
          random,
          stoppedPolls: random.nextBool() ? 0 : pollsOfALongDraft,
          restartedPolls: pollsOfALongDraft,
          heldReplyTiming: _randomTiming(random),
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

        await repository.stopDrafting(request);
        await drafts.restarted.done;

        expect(drafts.restarted.hasFinished, isFalse);
        expect(drafts.restarted.errors, isEmpty);
        expect(node.cancelledRunIds, <String>[
          '$gatedRunIdPrefix${gatedTaskId(1)}',
          '$gatedRunIdPrefix${gatedTaskId(2)}',
        ]);
        expect(node.deletedTaskIds, <String>[gatedTaskId(1), gatedTaskId(2)]);
      }
    },
  );

  test('test_stop_drafting_property_a_second_stop_is_refused', () async {
    final Random random = seededRandom(52705);

    for (int i = 0; i < _restartIterations; i += 1) {
      final GatedItemDraftNode node = buildGatedNode(
        random,
        stoppedPolls: pollsOfALongDraft,
        restartedPolls: 0,
        heldReplyTiming: _randomTiming(random),
      );
      final NodeBackedItemDraftRepository repository = buildDraftRepository(
        node,
      );
      final ItemDraftRequest request = randomDraftRequest(random);
      final DraftLog stopped = listenToDraft(repository.draftItem(request));
      await waitUntil(() => node.heldPollCount > 0);
      await repository.stopDrafting(request);

      await expectLater(repository.stopDrafting(request), throwsStateError);

      node.releaseHeldReplies();
      await stopped.done;
      expect(node.cancelledRunIds, hasLength(1));
    }
  });

  test('test_stop_drafting_property_idle_requests_send_nothing', () async {
    final Random random = seededRandom(52706);

    for (int i = 0; i < _restartIterations; i += 1) {
      final GatedItemDraftNode node = buildGatedNode(
        random,
        stoppedPolls: 0,
        restartedPolls: 0,
        heldReplyTiming: _randomTiming(random),
      );
      final NodeBackedItemDraftRepository repository = buildDraftRepository(
        node,
      );

      await expectLater(
        repository.stopDrafting(randomDraftRequest(random)),
        throwsStateError,
      );

      expect(node.draftCount, 0);
      expect(node.cancelledRunIds, isEmpty);
    }
  });
}
