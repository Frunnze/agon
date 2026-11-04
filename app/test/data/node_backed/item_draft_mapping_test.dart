import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/item_draft_command_shapes.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../support/random_inputs.dart';

DraftKind _readDraftKind(JsonObject json) {
  return DraftKind.values.byName(json['kind']! as String);
}

void main() {
  test('test_map_drafted_item_to_node_property_round_trips_node_drafts', () {
    final Random random = seededRandom(8101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomItemDraftJson(random);
      final node.ItemDraft wire = node.ItemDraft.fromJson(json);

      final DraftedItem item = mapDraftedItemFromNode(wire);
      final node.ItemDraft mappedBack = mapDraftedItemToNode(
        item,
        _readDraftKind(json),
      );

      expect(mappedBack.toJson(), equals(json));
    }
  });

  test('test_map_item_draft_from_node_property_keeps_every_problem', () {
    final Random random = seededRandom(8102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> problems = <String>[
        for (final Object? problem in randomTexts(random)) problem! as String,
      ];
      final node.ItemDraftDone done = node.ItemDraftDone(
        draft: node.ItemDraft.fromJson(randomItemDraftJson(random)),
        problems: problems,
      );

      final ItemDraft draft = mapItemDraftFromNode(done);

      expect(draft.problems, equals(problems));
    }
  });

  test('test_map_draft_kind_to_node_property_keeps_the_kind_name', () {
    for (final DraftKind kind in DraftKind.values) {
      expect(mapDraftKindToNode(kind).wireName, kind.name);
    }
  });
}
