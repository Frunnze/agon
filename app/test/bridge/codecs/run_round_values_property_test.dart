import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_round_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_branching_json.dart';
import '../support/random_wire_values.dart';
import '../support/wire_contract_checks.dart';

const WireFields _earlierRoundFields = WireFields(
  requiredFields: <String>['status'],
  optionalFields: <String>['started_at', 'finished_at', 'result', 'outcome'],
  defaultedListFields: <String>[],
);

const WireFields _loopRoundsFields = WireFields(
  requiredFields: <String>['from', 'to', 'rounds'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

const WireFields _runNoteFields = WireFields(
  requiredFields: <String>['at', 'text'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

EarlierRound _randomLocalEarlierRound(Random random) {
  return EarlierRound(
    status: pickOne(random, StepStatus.values),
    startedAt: randomOptionalLocalMoment(random),
    finishedAt: randomOptionalLocalMoment(random),
    result: randomOptionalText(random),
    outcome: randomOptionalText(random),
  );
}

LoopRounds _randomLoopRounds(Random random) {
  return LoopRounds(
    from: randomText(random),
    to: randomText(random),
    rounds: randomWholeNumber(random),
  );
}

RunNote _randomLocalRunNote(Random random) {
  return RunNote(at: randomLocalMoment(random), text: randomText(random));
}

void main() {
  test('test_earlier_round_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(52901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomEarlierRoundJson(random);

      expectRequiredFieldsAreNeeded(
        json,
        _earlierRoundFields,
        EarlierRound.fromJson,
      );
      expectOptionalFieldsMayBeLeftOut(
        random,
        json,
        _earlierRoundFields,
        EarlierRound.fromJson,
      );
    }
  });

  test('test_earlier_round_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(52902);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomEarlierRoundJson(random),
        EarlierRound.fromJson,
      );
    }
  });

  test('test_earlier_round_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(52903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomEarlierRoundJson(random);

      final EarlierRound round = EarlierRound.fromJson(
        withUnknownFields(random, json),
      );

      expect(round.status.wireName, json['status']);
      expectSameMoment(round.startedAt, json['started_at']);
      expectSameMoment(round.finishedAt, json['finished_at']);
      expect(round.result, json['result']);
      expect(round.outcome, json['outcome']);
    }
  });

  test('test_earlier_round_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(52904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomLocalEarlierRound(random).toJson();

      expect(encoded.keys.toSet(), equals(_earlierRoundFields.everyField));
    }
  });

  test('test_earlier_round_to_json_property_values_mirror_round_in_utc', () {
    final Random random = seededRandom(52905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EarlierRound round = _randomLocalEarlierRound(random);

      final JsonObject encoded = round.toJson();

      expect(encoded['status'], round.status.wireName);
      expectOptionalUtcMomentText(encoded['started_at'], round.startedAt);
      expectOptionalUtcMomentText(encoded['finished_at'], round.finishedAt);
      expect(encoded['result'], round.result);
      expect(encoded['outcome'], round.outcome);
    }
  });

  test('test_earlier_round_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(52906);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _randomLocalEarlierRound(random),
        EarlierRound.fromJson,
      );
    }
  });

  test('test_loop_rounds_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(52907);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRequiredFieldsAreNeeded(
        randomLoopRoundsJson(random),
        _loopRoundsFields,
        LoopRounds.fromJson,
      );
    }
  });

  test('test_loop_rounds_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(52908);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomLoopRoundsJson(random),
        LoopRounds.fromJson,
      );
    }
  });

  test('test_loop_rounds_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(52909);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = withFieldValue(
        randomLoopRoundsJson(random),
        'rounds',
        randomWholeNumber(random),
      );

      final LoopRounds loop = LoopRounds.fromJson(
        withUnknownFields(random, json),
      );

      expect(loop.from, json['from']);
      expect(loop.to, json['to']);
      expect(loop.rounds, json['rounds']);
    }
  });

  test('test_loop_rounds_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(52910);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomLoopRounds(random).toJson();

      expect(encoded.keys.toSet(), equals(_loopRoundsFields.everyField));
    }
  });

  test('test_loop_rounds_to_json_property_values_mirror_the_loop', () {
    final Random random = seededRandom(52911);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopRounds loop = _randomLoopRounds(random);

      final JsonObject encoded = loop.toJson();

      expect(encoded['from'], loop.from);
      expect(encoded['to'], loop.to);
      expect(encoded['rounds'], loop.rounds);
    }
  });

  test('test_loop_rounds_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(52912);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _randomLoopRounds(random),
        LoopRounds.fromJson,
      );
    }
  });

  test('test_run_note_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(52913);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRequiredFieldsAreNeeded(
        randomRunNoteJson(random),
        _runNoteFields,
        RunNote.fromJson,
      );
    }
  });

  test('test_run_note_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(52914);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomRunNoteJson(random),
        RunNote.fromJson,
      );
    }
  });

  test('test_run_note_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(52915);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunNoteJson(random);

      final RunNote note = RunNote.fromJson(withUnknownFields(random, json));

      expectSameMoment(note.at, json['at']);
      expect(note.text, json['text']);
    }
  });

  test('test_run_note_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(52916);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomLocalRunNote(random).toJson();

      expect(encoded.keys.toSet(), equals(_runNoteFields.everyField));
    }
  });

  test('test_run_note_to_json_property_values_mirror_the_note_in_utc', () {
    final Random random = seededRandom(52917);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunNote note = _randomLocalRunNote(random);

      final JsonObject encoded = note.toJson();

      expectUtcMomentText(encoded['at'], note.at);
      expect(encoded['text'], note.text);
    }
  });

  test('test_run_note_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(52918);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _randomLocalRunNote(random),
        RunNote.fromJson,
      );
    }
  });
}
