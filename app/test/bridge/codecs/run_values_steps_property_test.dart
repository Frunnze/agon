import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_round_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/node_json_primitives.dart';
import '../support/random_branching_json.dart';
import '../support/random_run_json.dart';
import '../support/random_typed_values.dart';
import '../support/random_wire_values.dart';
import '../support/wire_contract_checks.dart';
import '../support/wire_name_checks.dart';

const WireFields _runStepFields = WireFields(
  requiredFields: <String>['name', 'status'],
  optionalFields: <String>[
    'agent_id',
    'runner',
    'started_at',
    'finished_at',
    'result',
    'outcome',
    'loop_source',
  ],
  defaultedListFields: <String>['earlier_rounds'],
);

List<EarlierRound> _randomEarlierRounds(Random random) {
  final List<EarlierRound> rounds = <EarlierRound>[];
  for (final Object? json in randomListOf(random, randomEarlierRoundJson)) {
    rounds.add(EarlierRound.fromJson(json));
  }
  return rounds;
}

RunStep _buildLocalRunStep(Random random, List<EarlierRound> earlierRounds) {
  final bool hasAgent = random.nextBool();
  return RunStep(
    name: randomText(random),
    agentId: hasAgent ? WorkflowAgentId(randomUuidText(random)) : null,
    runner: random.nextBool() ? null : randomDeviceId(random),
    status: pickOne(random, StepStatus.values),
    startedAt: randomOptionalLocalMoment(random),
    finishedAt: randomOptionalLocalMoment(random),
    result: randomOptionalText(random),
    outcome: randomOptionalText(random),
    loopSource: randomOptionalText(random),
    earlierRounds: earlierRounds,
  );
}

void main() {
  test('test_step_status_decode_property_reads_every_wire_name', () {
    expectDecodesEveryWireName(StepStatus.values, StepStatus.decode);
  });

  test('test_step_status_decode_property_rejects_near_misses', () {
    final Random random = seededRandom(53101);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsNearMissWireNames(
        random,
        StepStatus.values,
        StepStatus.decode,
      );
    }
  });

  test('test_step_status_decode_property_rejects_non_text', () {
    final Random random = seededRandom(53102);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsWireNamesOfAnotherKind(
        random,
        StepStatus.values,
        StepStatus.decode,
      );
    }
  });

  test('test_run_status_decode_property_reads_every_wire_name', () {
    expectDecodesEveryWireName(RunStatus.values, RunStatus.decode);
  });

  test('test_run_status_decode_property_rejects_near_misses', () {
    final Random random = seededRandom(53103);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsNearMissWireNames(
        random,
        RunStatus.values,
        RunStatus.decode,
      );
    }
  });

  test('test_run_status_decode_property_rejects_non_text', () {
    final Random random = seededRandom(53104);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsWireNamesOfAnotherKind(
        random,
        RunStatus.values,
        RunStatus.decode,
      );
    }
  });

  test('test_run_step_property_keeps_earlier_rounds_in_order', () {
    final Random random = seededRandom(53105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<EarlierRound> rounds = _randomEarlierRounds(random);

      final RunStep step = _buildLocalRunStep(random, rounds);

      expect(step.earlierRounds, orderedEquals(rounds));
    }
  });

  test('test_run_step_property_ignores_later_caller_changes', () {
    final Random random = seededRandom(53106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<EarlierRound> rounds = _randomEarlierRounds(random);
      final EarlierRound extra = EarlierRound.fromJson(
        randomEarlierRoundJson(random),
      );

      final RunStep step = _buildLocalRunStep(random, rounds);

      expectListIgnoresCallerChanges(rounds, step.earlierRounds, extra);
    }
  });

  test('test_run_step_property_earlier_rounds_refuse_changes', () {
    final Random random = seededRandom(53107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunStep step = _buildLocalRunStep(
        random,
        _randomEarlierRounds(random),
      );
      final EarlierRound extra = EarlierRound.fromJson(
        randomEarlierRoundJson(random),
      );

      expectListRefusesChanges(step.earlierRounds, extra);
    }
  });

  test('test_run_step_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(53108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunStepJson(random);

      expectRequiredFieldsAreNeeded(json, _runStepFields, RunStep.fromJson);
      expectOptionalFieldsMayBeLeftOut(
        random,
        json,
        _runStepFields,
        RunStep.fromJson,
      );
    }
  });

  test('test_run_step_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(53109);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomRunStepJson(random),
        RunStep.fromJson,
      );
    }
  });

  test('test_run_step_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(53110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunStepJson(random);

      final RunStep step = RunStep.fromJson(withUnknownFields(random, json));

      expect(step.name, json['name']);
      expect(step.agentId?.value, json['agent_id']);
      expect(step.runner?.value, json['runner']);
      expect(step.status.wireName, json['status']);
      expectSameMoment(step.startedAt, json['started_at']);
      expectSameMoment(step.finishedAt, json['finished_at']);
      expect(step.result, json['result']);
      expect(step.outcome, json['outcome']);
      expect(step.loopSource, json['loop_source']);
      expect(encodeList(step.earlierRounds), equals(json['earlier_rounds']));
    }
  });

  test('test_run_step_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(53111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunStep step = _buildLocalRunStep(
        random,
        _randomEarlierRounds(random),
      );

      expect(step.toJson().keys.toSet(), equals(_runStepFields.everyField));
    }
  });

  test('test_run_step_to_json_property_values_mirror_the_step_in_utc', () {
    final Random random = seededRandom(53112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunStep step = _buildLocalRunStep(
        random,
        _randomEarlierRounds(random),
      );

      final JsonObject encoded = step.toJson();

      expect(encoded['name'], step.name);
      expect(encoded['agent_id'], step.agentId?.value);
      expect(encoded['runner'], step.runner?.value);
      expect(encoded['status'], step.status.wireName);
      expectOptionalUtcMomentText(encoded['started_at'], step.startedAt);
      expectOptionalUtcMomentText(encoded['finished_at'], step.finishedAt);
      expect(encoded['result'], step.result);
      expect(encoded['outcome'], step.outcome);
      expect(encoded['loop_source'], step.loopSource);
      expect(
        encoded['earlier_rounds'],
        equals(encodeList(step.earlierRounds)),
      );
    }
  });

  test('test_run_step_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(53113);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunStep step = _buildLocalRunStep(
        random,
        _randomEarlierRounds(random),
      );

      expectPlainJsonThatDecodesBack(step, RunStep.fromJson);
    }
  });
}
