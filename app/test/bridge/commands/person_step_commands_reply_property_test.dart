import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/person_step_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/bridge/commands/person_step_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/arbitrary_json.dart';
import '../support/decoding_outcome.dart';
import '../support/hostile_texts.dart';
import '../support/random_branching_json.dart';
import '../support/random_run_json.dart';
import '../support/wire_contract_checks.dart';

const int _firstSeed = 5918000;
const int _largestStepCount = 7;
const ListPersonStepsCommand _listCommand = ListPersonStepsCommand();
const AnswerPersonStepCommand _anyAnswerCommand = AnswerPersonStepCommand(
  runId: RunId('any run'),
  stepName: 'any step',
  answer: 'any answer',
);

const WireFields _openPersonStepFields = WireFields(
  requiredFields: <String>[
    'run_id',
    'task_id',
    'workspace_id',
    'step_name',
    'question',
    'choices',
  ],
  optionalFields: <String>['asked_at'],
  defaultedListFields: <String>[],
);

const WireFields _runFields = WireFields(
  requiredFields: <String>[
    'id',
    'task_id',
    'number',
    'status',
    'steps',
    'log',
    'chat',
    'link',
    'started_by',
    'started_at',
  ],
  optionalFields: <String>[
    'failure',
    'link_lost_at',
    'agent_session',
    'worktree_branch',
    'finished_at',
  ],
  defaultedListFields: <String>['loop_rounds', 'notes'],
);

AnswerPersonStepCommand _randomAnswerCommand(Random random) {
  return AnswerPersonStepCommand(
    runId: RunId(randomHostileText(random)),
    stepName: randomHostileText(random),
    answer: randomHostileText(random),
  );
}

JsonEncodable _decodeAnswerReply(Object? replyJson) {
  return _anyAnswerCommand.decodeReply(replyJson);
}

JsonEncodable _decodeOneListedStep(Object? stepJson) {
  final List<Object?> listedStepJson = <Object?>[stepJson];
  return _listCommand.decodeReply(listedStepJson).single;
}

List<Object?> _randomOpenPersonStepsJson(Random random) {
  final int stepCount = 1 + random.nextInt(_largestStepCount);
  final List<Object?> stepsJson = <Object?>[];
  for (int i = 0; i < stepCount; i += 1) {
    stepsJson.add(randomOpenPersonStepJson(random));
  }
  return stepsJson;
}

Object? _randomBrokenStep(Random random, JsonObject stepJson) {
  final String requiredField = pickOne(
    random,
    _openPersonStepFields.requiredFields,
  );
  final List<Object?> brokenSteps = <Object?>[
    null,
    randomHostileText(random),
    random.nextInt(1 << 31),
    <Object?>[stepJson],
    withoutField(stepJson, requiredField),
    withFieldValue(stepJson, requiredField, null),
  ];
  return pickOne(random, brokenSteps);
}

Object? _randomReplyThatIsNotAList(Random random, List<Object?> stepsJson) {
  final List<Object?> replies = <Object?>[
    null,
    random.nextBool(),
    random.nextInt(1 << 31),
    randomHostileText(random),
    stepsJson.first,
    <String, Object?>{'steps': stepsJson},
  ];
  return pickOne(random, replies);
}

void main() {
  test('test_list_person_steps_command_decode_reply_property_'
      'keeps_every_step_in_order', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> stepsJson = _randomOpenPersonStepsJson(random);
      final List<OpenPersonStep> steps = _listCommand.decodeReply(
        rereadThroughWire(stepsJson),
      );

      expect(steps, hasLength(stepsJson.length));
      expect(rereadThroughWire(encodeList(steps)), equals(stepsJson));
    }
  });

  test('test_list_person_steps_command_decode_reply_property_'
      'one_broken_step_rejects_the_whole_list', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> stepsJson = _randomOpenPersonStepsJson(random);
      final int brokenIndex = random.nextInt(stepsJson.length);
      final JsonObject stepJson = decodeObject(stepsJson[brokenIndex]);
      final List<Object?> brokenStepsJson = List<Object?>.of(stepsJson);
      brokenStepsJson[brokenIndex] = _randomBrokenStep(random, stepJson);

      expect(
        () => _listCommand.decodeReply(brokenStepsJson),
        throwsFormatException,
        reason: '${brokenStepsJson[brokenIndex]}',
      );
    }
  });

  test('test_list_person_steps_command_decode_reply_property_'
      'rejects_replies_that_are_not_lists', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> stepsJson = _randomOpenPersonStepsJson(random);
      final Object? brokenReply = _randomReplyThatIsNotAList(
        random,
        stepsJson,
      );

      expect(
        () => _listCommand.decodeReply(brokenReply),
        throwsFormatException,
        reason: '$brokenReply',
      );
    }
  });

  test('test_list_person_steps_command_decode_reply_property_'
      'each_step_needs_its_fields', () {
    final Random random = seededRandom(_firstSeed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject stepJson = randomOpenPersonStepJson(random);

      expectRequiredFieldsAreNeeded(
        stepJson,
        _openPersonStepFields,
        _decodeOneListedStep,
      );
      expectOptionalFieldsMayBeLeftOut(
        random,
        stepJson,
        _openPersonStepFields,
        _decodeOneListedStep,
      );
    }
  });

  test('test_answer_person_step_command_decode_reply_property_'
      'reads_the_run_from_json_text', () {
    final Random random = seededRandom(_firstSeed + 10);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject runJson = randomRunJson(random);
      final Run run = _randomAnswerCommand(random)
          .decodeReply(rereadThroughWire(runJson));

      expect(rereadThroughWire(run.toJson()), equals(runJson));
      expect(run.id.value, runJson['id']);
    }
  });

  test('test_answer_person_step_command_decode_reply_property_'
      'needs_the_run_fields', () {
    final Random random = seededRandom(_firstSeed + 11);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject runJson = randomRunJson(random);

      expectRequiredFieldsAreNeeded(runJson, _runFields, _decodeAnswerReply);
      expectOptionalFieldsMayBeLeftOut(
        random,
        runJson,
        _runFields,
        _decodeAnswerReply,
      );
    }
  });

  test('test_answer_person_step_command_decode_reply_property_'
      'rejects_wrong_kinds_and_non_objects', () {
    final Random random = seededRandom(_firstSeed + 12);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject runJson = randomRunJson(random);
      final Object? brokenReply = pickOne(random, <Object?>[
        null,
        randomHostileText(random),
        random.nextInt(1 << 31),
        <Object?>[runJson],
      ]);

      expectWrongKindValuesAreRejected(random, runJson, _decodeAnswerReply);
      expect(
        () => _decodeAnswerReply(brokenReply),
        throwsFormatException,
        reason: '$brokenReply',
      );
    }
  });

  test('test_answer_person_step_command_decode_reply_property_'
      'hostile_replies_raise_only_format_errors', () {
    final Random random = seededRandom(_firstSeed + 13);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? mutatedReply = mutateJson(random, randomRunJson(random));
      final AnswerPersonStepCommand command = _randomAnswerCommand(random);

      expect(
        attemptDecoding(() => command.decodeReply(mutatedReply)),
        isIn(DecodingOutcome.values),
      );
    }
  });
}
