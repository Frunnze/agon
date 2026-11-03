import 'dart:convert';
import 'dart:math';

import '../../../bridge/support/random_branching_json.dart';
import '../../../bridge/support/random_run_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';
import 'simulated_work_node.dart';

final class SimulatedPersonStepNode {
  final List<WireRecord> openSteps = <WireRecord>[];
  final List<String> receivedAnswers = <String>[];
  final Random _random = Random(0);

  String answer(String inputJson) {
    final WireRecord command = jsonDecode(inputJson) as WireRecord;
    final String name = command['command']! as String;
    return switch (name) {
      'list_person_steps' => encodeSuccessReply(openSteps),
      'answer_person_step' => _answerStep(command),
      _ => encodeErrorReply('unknown command: $name'),
    };
  }

  void askFromElsewhere(Random random) {
    final WireRecord openStep = randomOpenPersonStepJson(random);
    openStep['step_name'] = 'step-${openSteps.length}';
    openSteps.add(openStep);
  }

  String _answerStep(WireRecord command) {
    final int index = openSteps.indexWhere(
      (WireRecord openStep) =>
          openStep['run_id'] == command['run_id'] &&
          openStep['step_name'] == command['step_name'],
    );
    if (index < 0) {
      return encodeErrorReply(
        'open person step ${command['step_name']} was not found',
      );
    }
    receivedAnswers.add(command['answer']! as String);
    openSteps.removeAt(index);
    return encodeSuccessReply(randomRunJson(_random));
  }
}
