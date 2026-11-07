import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';

import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_app_server_refusals.dart';
import '../../support/random_inputs.dart';
import 'support/held_next_reply_transport.dart';
import 'support/item_draft_restarts.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_item_draft_node.dart';

const int _draftIterations = 40;
const int _largestPollMilliseconds = 60000;
const int _pumpLimit = 50;
const Duration _oneMillisecond = Duration(milliseconds: 1);

typedef _HeldStart = ({
  SimulatedItemDraftNode node,
  HeldNextReplyTransport transport,
  NodeBackedItemDraftRepository repository,
});

_HeldStart _buildHeldStart(Random random) {
  final SimulatedItemDraftNode simulated = SimulatedItemDraftNode(
    random: random,
    pollsBeforeDone: pollsOfALongDraft,
    finishedStatus: randomDoneStatus(random),
  );
  final HeldNextReplyTransport transport = HeldNextReplyTransport(
    answer: simulated.answer,
  );
  transport.holdNextReply('draft_item');
  return (
    node: simulated,
    transport: transport,
    repository: NodeBackedItemDraftRepository(
      channel: NodeCommandChannel(transport: transport),
      workspaceRepository: buildSingleWorkspaceRepository(),
      pollInterval: Duration.zero,
    ),
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() isReached) async {
  for (int pump = 0; pump < _pumpLimit && !isReached(); pump += 1) {
    await tester.pump(Duration.zero);
  }
  expect(isReached(), isTrue);
}

void main() {
  test(
    'test_running_item_draft_constructor_property_one_start_per_draft',
    () async {
      final Random random = seededRandom(77201);
      for (int i = 0; i < _draftIterations; i += 1) {
        final _HeldStart held = _buildHeldStart(random);
        final ItemDraftRequest request = randomDraftRequest(random);
        final DraftLog log = listenToDraft(held.repository.draftItem(request));
        await held.transport.heldReplyArrival;

        final Future<void> stopping = held.repository.stopDrafting(request);
        held.transport.releaseHeldReply();
        await stopping;
        await log.done;

        expect(held.node.commandsNamed('draft_item').length, 1);
        expect(held.node.cancelledRunIds, <String>[simulatedDraftingRunId]);
        expect(held.node.deletedTaskIds, <String>[simulatedDraftingTaskId]);
        expect(log.hasFinished, isFalse);
        expect(log.errors, isEmpty);
      }
    },
  );

  test(
    'test_running_item_draft_constructor_property_refused_start_frees_it',
    () async {
      final Random random = seededRandom(77202);
      for (int i = 0; i < propertyIterations; i += 1) {
        final RandomRefusal refusal = randomRefusal(random);
        final NodeBackedItemDraftRepository repository =
            NodeBackedItemDraftRepository(
              channel: buildSimulatedChannel(
                (String inputJson) => encodeErrorReply(refusal.nodeMessage),
              ),
              workspaceRepository: buildSingleWorkspaceRepository(),
              pollInterval: Duration.zero,
            );
        final ItemDraftRequest request = randomDraftRequest(random);

        await expectLater(
          repository.draftItem(request).toList(),
          throwsA(
            isA<AppServerRefusal>().having(
              (AppServerRefusal problem) => problem.message,
              'reason',
              refusal.reason,
            ),
          ),
        );

        await expectLater(repository.stopDrafting(request), throwsStateError);
        await expectLater(
          repository.draftItem(request).toList(),
          throwsA(isA<AppServerRefusal>()),
        );
      }
    },
  );

  test(
    'test_running_item_draft_constructor_property_stop_waits_for_start',
    () async {
      final Random random = seededRandom(77203);
      for (int i = 0; i < _draftIterations; i += 1) {
        final _HeldStart held = _buildHeldStart(random);
        final ItemDraftRequest request = randomDraftRequest(random);
        final DraftLog log = listenToDraft(held.repository.draftItem(request));
        await held.transport.heldReplyArrival;
        bool hasStopped = false;

        final Future<void> stopping = held.repository
            .stopDrafting(request)
            .then((void _) => hasStopped = true);
        await pumpEventQueue();
        expect(hasStopped, isFalse);
        expect(held.node.commandsNamed('cancel_run'), isEmpty);
        held.transport.releaseHeldReply();
        await stopping;
        await log.done;

        expect(hasStopped, isTrue);
        expect(held.node.commandsNamed('cancel_run').length, 1);
      }
    },
  );

  testWidgets(
    'test_node_backed_item_draft_repository_constructor_property_poll_spacing',
    (WidgetTester tester) async {
      final Random random = seededRandom(77204);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Duration interval = Duration(
          milliseconds: 2 + random.nextInt(_largestPollMilliseconds),
        );
        final SimulatedItemDraftNode simulated = SimulatedItemDraftNode(
          random: random,
          pollsBeforeDone: pollsOfALongDraft,
          finishedStatus: randomDoneStatus(random),
        );
        final NodeBackedItemDraftRepository repository =
            NodeBackedItemDraftRepository(
              channel: simulated.channel,
              workspaceRepository: buildSingleWorkspaceRepository(),
              pollInterval: interval,
            );
        final ItemDraftRequest request = randomDraftRequest(random);
        final DraftLog log = listenToDraft(repository.draftItem(request));

        await _pumpUntil(tester, () => simulated.statusPollCount == 1);
        await tester.pump(interval - _oneMillisecond);
        expect(simulated.statusPollCount, 1);
        await tester.pump(_oneMillisecond);
        await _pumpUntil(tester, () => simulated.statusPollCount == 2);

        final Future<void> stopping = repository.stopDrafting(request);
        await _pumpUntil(tester, () => simulated.deletedTaskIds.isNotEmpty);
        await tester.pump(interval);
        await stopping;
        await log.done;

        expect(log.hasFinished, isFalse);
        expect(log.errors, isEmpty);
      }
    },
  );
}
