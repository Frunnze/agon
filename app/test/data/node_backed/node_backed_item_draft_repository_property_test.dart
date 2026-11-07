import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/item_draft_command_shapes.dart';
import '../../support/random_inputs.dart';
import '../fakes/support/workspace_inputs.dart';
import 'support/item_draft_restarts.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_item_draft_node.dart';

const int _draftIterations = 40;

SimulatedItemDraftNode _buildNode(Random random, {required int polls}) {
  return SimulatedItemDraftNode(
    random: random,
    pollsBeforeDone: polls,
    finishedStatus: randomDoneStatus(random),
  );
}

NodeBackedItemDraftRepository _buildRepository(SimulatedItemDraftNode node) {
  return NodeBackedItemDraftRepository(
    channel: node.channel,
    workspaceRepository: buildSingleWorkspaceRepository(),
    pollInterval: Duration.zero,
  );
}

bool _isDraftOfKind(DraftedItem draft, DraftKind kind) {
  return switch (draft) {
    DraftedWork() => kind == DraftKind.task || kind == DraftKind.job,
    DraftedSkill() => kind == DraftKind.skill,
    DraftedRule() => kind == DraftKind.rule,
  };
}

void main() {
  test(
    'test_node_backed_item_draft_repository_constructor_property_starts_idle',
    () async {
      final Random random = seededRandom(77101);
      for (int i = 0; i < propertyIterations; i += 1) {
        final SimulatedItemDraftNode simulated = _buildNode(random, polls: 0);

        await expectLater(
          _buildRepository(simulated).stopDrafting(randomDraftRequest(random)),
          throwsStateError,
        );

        expect(simulated.commands, isEmpty);
      }
    },
  );

  test(
    'test_node_backed_item_draft_repository_constructor_property_own_drafts',
    () async {
      final Random random = seededRandom(77102);
      for (int i = 0; i < _draftIterations; i += 1) {
        final SimulatedItemDraftNode first = _buildNode(random, polls: 1);
        final SimulatedItemDraftNode second = _buildNode(random, polls: 1);
        final ItemDraftRequest request = randomDraftRequest(random);

        final List<List<ItemDraftProgress>> drafted = await Future.wait(
          <Future<List<ItemDraftProgress>>>[
            _buildRepository(first).draftItem(request).toList(),
            _buildRepository(second).draftItem(request).toList(),
          ],
        );

        expect(drafted.first.last, isA<DraftFinished>());
        expect(drafted.last.last, isA<DraftFinished>());
        expect(first.commandsNamed('draft_item').length, 1);
        expect(second.commandsNamed('draft_item').length, 1);
      }
    },
  );

  test(
    'test_build_draft_command_property_sends_the_request_as_typed',
    () async {
      final Random random = seededRandom(77103);
      for (int i = 0; i < _draftIterations; i += 1) {
        final SimulatedItemDraftNode simulated = _buildNode(random, polls: 0);
        final ItemDraftRequest request = ItemDraftRequest(
          kind: pickOne(random, DraftKind.values),
          wish: ' wish ${randomHostileText(random)} ',
          startedFrom: random.nextBool() ? null : randomHostileText(random),
          change: null,
        );

        await _buildRepository(simulated).draftItem(request).toList();

        final JsonObject sent = simulated.commandsNamed('draft_item').single;
        expect(sent['kind'], mapDraftKindToNode(request.kind).wireName);
        expect(sent['request'], request.wish);
        expect(sent['started_from'], request.startedFrom);
        expect(sent['change'], isNull);
        final JsonObject polled = simulated
            .commandsNamed('item_draft_status')
            .first;
        expect(polled['kind'], sent['kind']);
      }
    },
  );

  test(
    'test_build_draft_command_property_keeps_the_workspace_of_the_start',
    () async {
      final Random random = seededRandom(77104);
      for (int i = 0; i < _draftIterations; i += 1) {
        final SimulatedItemDraftNode simulated = _buildNode(random, polls: 3);
        final SeededWorkspaces seeded = seedRandomWorkspaces(random);
        final FakeWorkspaceRepository workspaces = seeded.repository;
        final String startWorkspaceId = workspaces.currentWorkspace().id.value;
        final NodeBackedItemDraftRepository repository =
            NodeBackedItemDraftRepository(
              channel: simulated.channel,
              workspaceRepository: workspaces,
              pollInterval: Duration.zero,
            );

        final DraftLog log = listenToDraft(
          repository.draftItem(randomDraftRequest(random)),
        );
        await waitUntil(() => simulated.statusPollCount > 0);
        final Workspace other = pickOne(random, seeded.workspaces);
        await workspaces.switchWorkspace(other.id);
        await log.done;

        expect(log.hasFinished, isTrue);
        for (final JsonObject command in simulated.commands) {
          if (command.containsKey('workspace_id')) {
            expect(command['workspace_id'], startWorkspaceId);
          }
        }
      }
    },
  );

  test(
    'test_build_draft_command_property_a_mismatched_change_sends_nothing',
    () async {
      final Random random = seededRandom(77105);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DraftedItem previous = mapDraftedItemFromNode(
          node.ItemDraft.fromJson(randomItemDraftJson(random)),
        );
        final List<DraftKind> otherKinds = <DraftKind>[
          for (final DraftKind kind in DraftKind.values)
            if (!_isDraftOfKind(previous, kind)) kind,
        ];
        final SimulatedItemDraftNode simulated = _buildNode(random, polls: 0);
        final NodeBackedItemDraftRepository repository = _buildRepository(
          simulated,
        );
        final ItemDraftRequest request = ItemDraftRequest(
          kind: pickOne(random, otherKinds),
          wish: 'Change it',
          startedFrom: null,
          change: ItemDraftChange(draft: previous, note: 'note'),
        );

        await expectLater(
          repository.draftItem(request).toList(),
          throwsArgumentError,
        );

        expect(simulated.commands, isEmpty);
        await expectLater(repository.stopDrafting(request), throwsStateError);
      }
    },
  );
}
