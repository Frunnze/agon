import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/person_step_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class ListPersonStepsCommand
    implements NodeCommand<List<OpenPersonStep>> {
  const ListPersonStepsCommand();

  @override
  String get name => 'list_person_steps';

  @override
  JsonObject get arguments => noArguments;

  @override
  List<OpenPersonStep> decodeReply(Object? okValue) {
    return decodeList(okValue, OpenPersonStep.fromJson);
  }
}

final class AnswerPersonStepCommand implements NodeCommand<Run> {
  const AnswerPersonStepCommand({
    required this.runId,
    required this.stepName,
    required this.answer,
  });

  final RunId runId;
  final String stepName;
  final String answer;

  @override
  String get name => 'answer_person_step';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'run_id': runId.value,
      'step_name': stepName,
      'answer': answer,
    };
  }

  @override
  Run decodeReply(Object? okValue) => Run.fromJson(okValue);
}
