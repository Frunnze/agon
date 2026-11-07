import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../fakes/support/notification_counter.dart';
import '../../fakes/support/person_step_inputs.dart';
import 'held_next_reply_transport.dart';
import 'simulated_node_replies.dart';
import 'simulated_person_step_node.dart';
import 'simulated_work_node.dart';

const String listPersonStepsCommand = 'list_person_steps';
const String answerPersonStepCommand = 'answer_person_step';
const int _largestAskedCount = 6;

typedef StepKey = ({String runId, String stepName});

final class NodeBackedPersonStepRig {
  NodeBackedPersonStepRig() {
    repository.addListener(notifications.record);
  }

  final SimulatedPersonStepNode simulated = SimulatedPersonStepNode();
  final List<String> commandNames = <String>[];
  final Set<String> failingCommands = <String>{};
  final NotificationCounter notifications = NotificationCounter();
  late final HeldNextReplyTransport transport = HeldNextReplyTransport(
    answer: answer,
  );
  late final NodeBackedPersonStepRepository repository =
      NodeBackedPersonStepRepository(
        channel: NodeCommandChannel(transport: transport),
      );

  String answer(String inputJson) {
    final WireRecord command = jsonDecode(inputJson) as WireRecord;
    final String commandName = command['command']! as String;
    commandNames.add(commandName);
    if (failingCommands.contains(commandName)) {
      return encodeErrorReply(simulatedOutageMessage);
    }
    return simulated.answer(inputJson);
  }

  void askRandomSteps(Random random) {
    final int count = 1 + random.nextInt(_largestAskedCount);
    for (int i = 0; i < count; i += 1) {
      simulated.askFromElsewhere(random);
      simulated.openSteps.last['choices'] = randomStepChoices(random);
    }
  }

  List<StepKey> describeNodeSteps() {
    return <StepKey>[
      for (final WireRecord openStep in simulated.openSteps)
        if (!simulated.finishedRunIds.contains(openStep['run_id']))
          (
            runId: openStep['run_id']! as String,
            stepName: openStep['step_name']! as String,
          ),
    ];
  }

  List<StepKey> describeListedSteps() {
    return <StepKey>[
      for (final OpenPersonStep openStep in repository.listOpenPersonSteps())
        (runId: openStep.runId.value, stepName: openStep.stepName),
    ];
  }
}
