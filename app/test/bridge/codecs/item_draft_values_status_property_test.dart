import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/decoding_outcome.dart';
import '../support/hostile_texts.dart';
import '../support/item_draft_command_shapes.dart';
import '../support/random_item_drafts.dart';
import '../support/wire_contract_checks.dart';

const String _workingState = 'working';
const String _doneState = 'done';
const Set<String> _nodeStates = <String>{_workingState, _doneState};
const Set<String> _nodeDoneFields = <String>{'state', 'draft', 'problems'};

Object? _decodeJsonText(JsonObject json) => jsonDecode(jsonEncode(json));

JsonObject _randomDoneJson(Random random) {
  return <String, Object?>{
    'state': _doneState,
    'draft': randomItemDraftJson(random),
    'problems': randomHostileTexts(random),
  };
}

JsonObject _randomBrokenDoneJson(Random random) {
  final JsonObject json = _randomDoneJson(random);
  final String field = pickOne(random, <String>['draft', 'problems']);
  if (random.nextBool()) {
    json.remove(field);
    return json;
  }
  if (field == 'problems') {
    json[field] = <Object?>[randomHostileText(random), null];
    return json;
  }
  json[field] = randomHostileText(random);
  return json;
}

Object? _randomUnknownState(Random random) {
  final Object? arbitraryState = randomArbitraryJson(random);
  if (_nodeStates.contains(arbitraryState)) {
    return 'Working';
  }
  return pickOne(random, <Object?>[
    arbitraryState,
    'Done',
    ' done',
    'failed',
    'workflow',
  ]);
}

void main() {
  test('test_item_draft_status_from_json_property_round_trips_as_text', () {
    final Random random = seededRandom(51001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomItemDraftStatusJson(random);

      final ItemDraftStatus status = ItemDraftStatus.fromJson(json);

      expect(jsonDecode(jsonEncode(status.toJson())), equals(json));
    }
  });

  test('test_item_draft_status_from_json_property_state_picks_variant', () {
    final Random random = seededRandom(51002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject doneJson = _randomDoneJson(random);
      final JsonObject workingJson = <String, Object?>{
        'state': _workingState,
        'problems': randomHostileTexts(random),
      };

      final ItemDraftStatus done = ItemDraftStatus.fromJson(doneJson);
      final ItemDraftStatus working = ItemDraftStatus.fromJson(workingJson);

      expect(working, isA<ItemDraftWorking>());
      final ItemDraftDone doneStatus = done as ItemDraftDone;
      expect(
        doneStatus.problems,
        orderedEquals(doneJson['problems']! as List<Object?>),
      );
      expect(doneStatus.draft.toJson(), equals(doneJson['draft']));
    }
  });

  test('test_item_draft_status_from_json_property_rejects_bad_shapes', () {
    final Random random = seededRandom(51003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject unknownState = <String, Object?>{
        'state': _randomUnknownState(random),
        'draft': randomItemDraftJson(random),
        'problems': <Object?>[],
      };

      expect(
        () => ItemDraftStatus.fromJson(unknownState),
        throwsFormatException,
      );
      expect(
        () => ItemDraftStatus.fromJson(_randomBrokenDoneJson(random)),
        throwsFormatException,
      );
    }
  });

  test('test_item_draft_working_to_json_property_writes_only_the_state', () {
    expect(
      const ItemDraftWorking().toJson(),
      equals(<String, Object?>{'state': _workingState}),
    );
  });

  test('test_item_draft_working_to_json_property_decodes_back_to_working', () {
    final Random random = seededRandom(51004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = const ItemDraftWorking().toJson();
      json['draft'] = randomArbitraryJson(random);

      final ItemDraftStatus status = ItemDraftStatus.fromJson(
        _decodeJsonText(json),
      );

      expect(status, isA<ItemDraftWorking>());
    }
  });

  test('test_item_draft_working_to_json_property_gives_a_fresh_map', () {
    final JsonObject firstJson = const ItemDraftWorking().toJson();
    firstJson['state'] = _doneState;

    final JsonObject secondJson = const ItemDraftWorking().toJson();

    expect(secondJson['state'], _workingState);
  });

  test('test_item_draft_done_constructor_property_keeps_its_own_copy', () {
    final Random random = seededRandom(51005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> problems = randomHostileTexts(random);

      final ItemDraftDone done = ItemDraftDone(
        draft: randomTypedItemDraft(random),
        problems: problems,
      );

      expectListIgnoresCallerChanges(
        problems,
        done.problems,
        randomHostileText(random),
      );
    }
  });

  test('test_item_draft_done_constructor_property_problems_are_frozen', () {
    final Random random = seededRandom(51006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ItemDraftDone done = ItemDraftDone(
        draft: randomTypedItemDraft(random),
        problems: randomHostileTexts(random),
      );

      expectListRefusesChanges(done.problems, randomHostileText(random));
    }
  });

  test('test_item_draft_done_constructor_property_keeps_draft_and_order', () {
    final Random random = seededRandom(51007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ItemDraft draft = randomTypedItemDraft(random);
      final String repeatedProblem = randomHostileText(random);
      final List<String> problems = <String>[
        repeatedProblem,
        ...randomHostileTexts(random),
        repeatedProblem,
      ];

      final ItemDraftDone done = ItemDraftDone(
        draft: draft,
        problems: problems,
      );

      expect(done.draft, same(draft));
      expect(done.problems, orderedEquals(problems));
    }
  });

  test('test_item_draft_done_to_json_property_round_trips_as_text', () {
    final Random random = seededRandom(51008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ItemDraftDone done = ItemDraftDone(
        draft: randomTypedItemDraft(random),
        problems: randomHostileTexts(random),
      );

      final ItemDraftStatus decoded = ItemDraftStatus.fromJson(
        _decodeJsonText(done.toJson()),
      );

      final ItemDraftDone decodedDone = decoded as ItemDraftDone;
      expect(decodedDone.problems, orderedEquals(done.problems));
      expect(decodedDone.draft.toJson(), equals(done.draft.toJson()));
    }
  });

  test('test_item_draft_done_to_json_property_writes_the_node_fields', () {
    final Random random = seededRandom(51009);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ItemDraftDone done = ItemDraftDone(
        draft: randomTypedItemDraft(random),
        problems: randomHostileTexts(random),
      );

      final JsonObject json = done.toJson();

      expect(json.keys.toSet(), equals(_nodeDoneFields));
      expect(json['state'], _doneState);
      expect(json['draft'], equals(done.draft.toJson()));
      expect(json['problems'], orderedEquals(done.problems));
    }
  });

  test('test_item_draft_done_to_json_property_is_stable_across_trips', () {
    final Random random = seededRandom(51010);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = _randomDoneJson(random);

      final Object? encoded = ItemDraftStatus.fromJson(json).toJson();

      expect(jsonDecode(jsonEncode(encoded)), equals(json));
    }
  });

  test(
    'test_item_draft_status_from_json_property_malformed_raises_format',
    () {
      final Random random = seededRandom(51011);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Object? mutatedJson = mutateJson(
          random,
          randomItemDraftStatusJson(random),
        );

        expect(
          attemptDecoding(() => ItemDraftStatus.fromJson(mutatedJson)),
          isIn(DecodingOutcome.values),
        );
      }
    },
  );
}
