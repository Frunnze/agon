import 'dart:async';
import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/support/item_draft_command_shapes.dart';
import '../../../support/random_inputs.dart';
import 'gated_item_draft_node.dart';
import 'node_backed_harness.dart';

const int pollsOfALongDraft = 1000000;

final class DraftLog {
  final List<ItemDraftProgress> progress = <ItemDraftProgress>[];
  final List<Object> errors = <Object>[];
  final Completer<void> _finished = Completer<void>();

  Future<void> get done => _finished.future;

  bool get hasFinished => progress.whereType<DraftFinished>().isNotEmpty;

  void _recordError(Object error) => errors.add(error);
}

typedef StopAndRestart = ({DraftLog stopped, DraftLog restarted});

DraftLog listenToDraft(Stream<ItemDraftProgress> drafting) {
  final DraftLog log = DraftLog();
  drafting.listen(
    log.progress.add,
    onError: log._recordError,
    onDone: log._finished.complete,
  );
  return log;
}

Future<void> waitUntil(bool Function() isReached) async {
  await Future<void>.delayed(Duration.zero);
  while (!isReached()) {
    await Future<void>.delayed(Duration.zero);
  }
}

JsonObject randomDoneStatus(Random random) {
  return <String, Object?>{
    'state': 'done',
    'draft': randomItemDraftJson(random),
    'problems': const <Object?>[],
  };
}

ItemDraftRequest randomDraftRequest(Random random) {
  return ItemDraftRequest(
    kind: pickOne(random, DraftKind.values),
    wish: 'Wish ${randomText(random)}',
    startedFrom: random.nextBool() ? null : randomText(random),
    change: null,
  );
}

GatedItemDraftNode buildGatedNode(
  Random random, {
  required int stoppedPolls,
  required int restartedPolls,
  required HeldReplyTiming heldReplyTiming,
}) {
  return GatedItemDraftNode(
    random: random,
    pollsBeforeDoneByTask: <String, int>{
      gatedTaskId(1): stoppedPolls,
      gatedTaskId(2): restartedPolls,
      gatedTaskId(3): restartedPolls,
    },
    finishedStatus: randomDoneStatus(random),
    heldTaskId: gatedTaskId(1),
    heldReplyTiming: heldReplyTiming,
  );
}

NodeBackedItemDraftRepository buildDraftRepository(GatedItemDraftNode node) {
  return NodeBackedItemDraftRepository(
    channel: node.channel,
    workspaceRepository: buildSingleWorkspaceRepository(),
    pollInterval: Duration.zero,
  );
}

Future<StopAndRestart> stopThenDraftAgain(
  GatedItemDraftNode node,
  NodeBackedItemDraftRepository repository,
  ItemDraftRequest request,
) async {
  final DraftLog stopped = listenToDraft(repository.draftItem(request));
  await waitUntil(() => node.heldPollCount > 0);
  await repository.stopDrafting(request);

  final DraftLog restarted = listenToDraft(repository.draftItem(request));
  await waitUntil(() => node.draftCount == 2);
  node.releaseHeldReplies();
  await stopped.done;
  return (stopped: stopped, restarted: restarted);
}
