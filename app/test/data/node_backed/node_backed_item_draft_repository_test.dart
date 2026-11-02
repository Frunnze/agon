import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/item_draft_command_shapes.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_item_draft_node.dart';

const int _draftIterations = 30;
const int _pollsOfALongDraft = 1000000;
const int _mostChosenFolders = 3;

JsonObject _randomDoneStatus(Random random) {
  return <String, Object?>{
    'state': 'done',
    'draft': randomItemDraftJson(random),
    'problems': <Object?>[
      for (int i = 0; i < random.nextInt(3); i += 1) 'p$i',
    ],
  };
}

NodeBackedItemDraftRepository _buildRepository(SimulatedItemDraftNode node) {
  return NodeBackedItemDraftRepository(
    channel: node.channel,
    workspaceRepository: buildSingleWorkspaceRepository(),
    pollInterval: Duration.zero,
  );
}

ItemDraftRequest _randomRequest(Random random, {ItemDraftChange? change}) {
  return ItemDraftRequest(
    kind: pickOne(random, DraftKind.values),
    wish: 'Wish ${randomText(random)}',
    startedFrom: random.nextBool() ? null : randomText(random),
    change: change,
    chosenFolders: const <RepositoryDraft>[],
  );
}

List<RepositoryDraft> _randomChosenFolders(Random random) {
  final int count = random.nextInt(_mostChosenFolders + 1);
  return <RepositoryDraft>[
    for (int i = 0; i < count; i += 1)
      RepositoryDraft(
        address: 'local:air-laptop:/Users/someone/${randomText(random)}',
        defaultBranch: randomText(random),
      ),
  ];
}

Future<void> _waitForPolls(SimulatedItemDraftNode node, int count) async {
  await Future<void>.delayed(Duration.zero);
  while (node.statusPollCount < count) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('test_draft_item_property_finishes_with_the_node_draft', () async {
    final Random random = seededRandom(8201);
    for (int i = 0; i < _draftIterations; i += 1) {
      final int polls = random.nextInt(4);
      final JsonObject finished = _randomDoneStatus(random);
      final SimulatedItemDraftNode simulated = SimulatedItemDraftNode(
        random: random,
        pollsBeforeDone: polls,
        finishedStatus: finished,
      );
      final ItemDraftRequest request = _randomRequest(random);

      final List<ItemDraftProgress> progress = await _buildRepository(
        simulated,
      ).draftItem(request).toList();

      expect(progress.whereType<DraftRunning>().length, polls);
      final DraftFinished last = progress.last as DraftFinished;
      final node.ItemDraftDone expected =
          node.ItemDraftStatus.fromJson(finished) as node.ItemDraftDone;
      expect(last.draft.problems, expected.problems);
      final JsonObject sent = simulated.commandsNamed('draft_item').single;
      expect(sent['kind'], request.kind.name);
      expect(sent['request'], request.wish);
      expect(sent['started_from'], request.startedFrom);
      expect(sent['change'], isNull);
      expect(sent['workspace_id'], harnessWorkspaceId.value);
    }
  });

  test('test_draft_item_property_sends_the_change_and_the_draft', () async {
    final Random random = seededRandom(8202);
    for (int i = 0; i < _draftIterations; i += 1) {
      final JsonObject previousJson = randomItemDraftJson(random);
      final DraftKind kind = DraftKind.values.byName(
        previousJson['kind']! as String,
      );
      final DraftedItem previous = mapDraftedItemFromNode(
        node.ItemDraft.fromJson(previousJson),
      );
      final String note = 'Change ${randomText(random)}';
      final SimulatedItemDraftNode simulated = SimulatedItemDraftNode(
        random: random,
        pollsBeforeDone: 0,
        finishedStatus: _randomDoneStatus(random),
      );
      final ItemDraftRequest request = ItemDraftRequest(
        kind: kind,
        wish: 'Wish',
        startedFrom: null,
        change: ItemDraftChange(draft: previous, note: note),
        chosenFolders: const <RepositoryDraft>[],
      );

      await _buildRepository(simulated).draftItem(request).toList();

      final JsonObject sent = simulated.commandsNamed('draft_item').single;
      expect(
        sent['change'],
        equals(<String, Object?>{'draft': previousJson, 'note': note}),
      );
    }
  });

  test(
    'test_draft_item_property_every_command_carries_chosen_folders',
    () async {
      final Random random = seededRandom(8205);
      for (int i = 0; i < _draftIterations; i += 1) {
        final List<RepositoryDraft> chosenFolders = _randomChosenFolders(
          random,
        );
        final SimulatedItemDraftNode simulated = SimulatedItemDraftNode(
          random: random,
          pollsBeforeDone: random.nextInt(4),
          finishedStatus: _randomDoneStatus(random),
        );
        final ItemDraftRequest request = ItemDraftRequest(
          kind: DraftKind.project,
          wish: 'Wish ${randomText(random)}',
          startedFrom: null,
          change: null,
          chosenFolders: chosenFolders,
        );

        await _buildRepository(simulated).draftItem(request).toList();

        final List<Object?> expected = <Object?>[
          for (final RepositoryDraft folder in chosenFolders)
            <String, Object?>{
              'address': folder.address,
              'default_branch': folder.defaultBranch,
            },
        ];
        final List<JsonObject> statusCommands = simulated.commandsNamed(
          'item_draft_status',
        );
        expect(statusCommands, isNotEmpty);
        for (final JsonObject sent in <JsonObject>[
          ...simulated.commandsNamed('draft_item'),
          ...statusCommands,
        ]) {
          expect(sent['chosen_folders'], equals(expected));
        }
      }
    },
  );

  test('test_stop_drafting_property_cancels_and_removes_the_run', () async {
    final Random random = seededRandom(8203);
    for (int i = 0; i < _draftIterations; i += 1) {
      final SimulatedItemDraftNode simulated = SimulatedItemDraftNode(
        random: random,
        pollsBeforeDone: _pollsOfALongDraft,
        finishedStatus: _randomDoneStatus(random),
      );
      final NodeBackedItemDraftRepository repository = _buildRepository(
        simulated,
      );
      final ItemDraftRequest request = _randomRequest(random);
      final List<ItemDraftProgress> received = <ItemDraftProgress>[];
      final Future<void> streaming = repository
          .draftItem(request)
          .forEach(received.add);
      await _waitForPolls(simulated, 1 + random.nextInt(3));

      await repository.stopDrafting(request);
      await streaming;

      expect(simulated.cancelledRunIds, <String>[simulatedDraftingRunId]);
      expect(simulated.deletedTaskIds, <String>[simulatedDraftingTaskId]);
      expect(received.whereType<DraftFinished>(), isEmpty);
      await expectLater(repository.stopDrafting(request), throwsStateError);
    }
  });

  test('test_draft_item_property_blank_wishes_send_nothing', () async {
    final Random random = seededRandom(8204);
    for (int i = 0; i < propertyIterations; i += 1) {
      final SimulatedItemDraftNode simulated = SimulatedItemDraftNode(
        random: random,
        pollsBeforeDone: 0,
        finishedStatus: _randomDoneStatus(random),
      );
      final String blank = ' ' * random.nextInt(4);
      final ItemDraftRequest request = ItemDraftRequest(
        kind: pickOne(random, DraftKind.values),
        wish: blank,
        startedFrom: null,
        change: null,
        chosenFolders: const <RepositoryDraft>[],
      );

      await expectLater(
        _buildRepository(simulated).draftItem(request).toList(),
        throwsArgumentError,
      );
      expect(simulated.commands, isEmpty);
    }
  });
}
