import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/commands/person_step_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/simple_command_properties.dart';
import '../support/wire_contract_checks.dart';
import 'support/command_member_row.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/fieldless_command_properties.dart';

const int _fieldSeed = 5917700;
const int _fieldlessSeed = 5917800;
const int _firstSeed = 5917900;
const String _runIdField = 'run_id';
const String _answerField = 'answer';

const List<ModelledCommandRow> _personStepFieldCommandRows =
    <ModelledCommandRow>[
      ModelledCommandRow(
        typeName: 'answer_person_step_command',
        commandName: 'answer_person_step',
        build: _buildAnswerPersonStep,
      ),
    ];

const List<CommandMemberRow> _personStepFieldlessCommandRows =
    <CommandMemberRow>[
      CommandMemberRow(
        typeName: 'list_person_steps_command',
        commandName: 'list_person_steps',
        construct: _constructListPersonSteps,
      ),
    ];

CommandConstruction _constructListPersonSteps(Random random) {
  return constructWithoutFields(const ListPersonStepsCommand());
}

ModelledCommand _buildAnswerPersonStep(Random random) {
  final RunId runId = RunId(randomArgumentText(random));
  final String stepName = randomArgumentText(random);
  final String answer = randomArgumentText(random);
  final AnswerPersonStepCommand command = AnswerPersonStepCommand(
    runId: runId,
    stepName: stepName,
    answer: answer,
  );
  return (
    command: command,
    givenFields: <Object?>[runId, stepName, answer],
    keptFields: <Object?>[command.runId, command.stepName, command.answer],
    expectedArguments: <String, Object?>{
      'run_id': runId.value,
      'step_name': stepName,
      'answer': answer,
    },
  );
}

void main() {
  testModelledCommandRows(_personStepFieldCommandRows, _fieldSeed);
  testFieldlessCommandRows(_personStepFieldlessCommandRows, _fieldlessSeed);

  test('test_answer_person_step_command_arguments_property_'
      'the_same_step_with_another_answer_differs_only_in_the_answer', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AnswerPersonStepCommand first =
          _buildAnswerPersonStep(random).command as AnswerPersonStepCommand;
      final String otherAnswer = randomArgumentText(random);
      final AnswerPersonStepCommand second = AnswerPersonStepCommand(
        runId: first.runId,
        stepName: first.stepName,
        answer: otherAnswer,
      );
      final JsonObject firstWireCommand = decodeObject(
        rereadThroughWire(encodeNodeCommand(first)),
      );
      final JsonObject expectedWireCommand = withFieldValue(
        firstWireCommand,
        _answerField,
        otherAnswer,
      );

      expect(
        rereadThroughWire(encodeNodeCommand(second)),
        equals(expectedWireCommand),
      );
    }
  });

  test('test_answer_person_step_command_arguments_property_'
      'sends_the_run_id_as_plain_text', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AnswerPersonStepCommand command =
          _buildAnswerPersonStep(random).command as AnswerPersonStepCommand;
      final JsonObject sentArguments = decodeObject(
        rereadThroughWire(command.arguments),
      );
      final Object? sentRunId = sentArguments[_runIdField];

      expect(sentRunId, isA<String>());
      expect(sentRunId, command.runId.value);
    }
  });
}
