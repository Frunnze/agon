import 'dart:math';

import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/commands/person_step_commands.dart';

import '../../support/random_inputs.dart';
import 'command_shape.dart';
import 'node_json_primitives.dart';
import 'random_branching_json.dart';
import 'random_run_json.dart';
import 'random_typed_values.dart';

const List<CommandShape> personStepCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'list_person_steps',
    argumentFields: <String>{},
    buildCommand: _buildListPersonSteps,
    buildReplyJson: _randomOpenPersonStepsJson,
    encodeReply: encodeListReply,
  ),
  CommandShape(
    commandName: 'answer_person_step',
    argumentFields: <String>{'run_id', 'step_name', 'answer'},
    buildCommand: _buildAnswerPersonStep,
    buildReplyJson: randomRunJson,
    encodeReply: encodeValueReply,
  ),
];

NodeCommand<Object?> _buildListPersonSteps(Random random) {
  return const ListPersonStepsCommand();
}

NodeCommand<Object?> _buildAnswerPersonStep(Random random) {
  return AnswerPersonStepCommand(
    runId: randomRunId(random),
    stepName: randomText(random),
    answer: randomText(random),
  );
}

List<Object?> _randomOpenPersonStepsJson(Random random) {
  return randomListOf(random, randomOpenPersonStepJson);
}
