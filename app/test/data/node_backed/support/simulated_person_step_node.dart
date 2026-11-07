import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/data/rules/person_answers.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

import '../../../bridge/support/random_branching_json.dart';
import '../../../bridge/support/random_run_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';
import 'simulated_work_node.dart';

const String simulatedEmptyAnswerRefusal = 'the answer cannot be empty';

final class SimulatedPersonStepNode {
  final List<WireRecord> openSteps = <WireRecord>[];
  final Set<Object?> finishedRunIds = <Object?>{};
  final List<String> receivedAnswers = <String>[];
  final Random _random = Random(0);

  String answer(String inputJson) {
    final WireRecord command = jsonDecode(inputJson) as WireRecord;
    final String name = command['command']! as String;
    return switch (name) {
      'list_person_steps' => encodeSuccessReply(_listAskedSteps()),
      'answer_person_step' => _answerStep(command),
      _ => encodeErrorReply('unknown command: $name'),
    };
  }

  void askFromElsewhere(Random random) {
    final WireRecord openStep = randomOpenPersonStepJson(random);
    openStep['step_name'] = 'step-${openSteps.length}';
    openSteps.add(openStep);
  }

  List<WireRecord> _listAskedSteps() {
    return <WireRecord>[
      for (final WireRecord openStep in openSteps)
        if (!finishedRunIds.contains(openStep['run_id'])) openStep,
    ];
  }

  String _answerStep(WireRecord command) {
    final String answer = command['answer']! as String;
    if (trimUnicodeWhiteSpace(answer).isEmpty) {
      return encodeErrorReply(simulatedEmptyAnswerRefusal);
    }
    final List<WireRecord> askedSteps = _listAskedSteps();
    final int index = askedSteps.indexWhere(
      (WireRecord openStep) =>
          openStep['run_id'] == command['run_id'] &&
          openStep['step_name'] == command['step_name'],
    );
    if (index < 0) {
      return encodeErrorReply(
        'open person step ${command['step_name']} was not found',
      );
    }
    final WireRecord asked = askedSteps[index];
    final List<String> choices = <String>[
      for (final Object? choice in asked['choices']! as List<Object?>)
        choice! as String,
    ];
    if (choices.isNotEmpty && matchChoice(answer, choices) == null) {
      return encodeErrorReply(describeUnmatchedAnswer(choices));
    }

    receivedAnswers.add(answer);
    openSteps.remove(asked);
    return encodeSuccessReply(randomRunJson(_random));
  }
}
