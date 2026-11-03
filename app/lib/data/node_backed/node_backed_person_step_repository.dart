import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/person_step_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/person_step_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/person_step_repository.dart';

final class NodeBackedPersonStepRepository extends ChangeNotifier
    implements PersonStepRepository, NodeSynchronized {
  NodeBackedPersonStepRepository({required NodeCommandChannel channel})
    : _channel = channel;

  final NodeCommandChannel _channel;
  List<OpenPersonStep> _openSteps = const <OpenPersonStep>[];

  @override
  List<OpenPersonStep> listOpenPersonSteps() => _openSteps;

  @override
  Future<void> load() async {
    final List<node.OpenPersonStep> openSteps = await executeNodeCommand(
      _channel,
      const node.ListPersonStepsCommand(),
    );

    _openSteps = List<OpenPersonStep>.unmodifiable(<OpenPersonStep>[
      for (final node.OpenPersonStep openStep in openSteps)
        mapOpenPersonStepFromNode(openStep),
    ]);
    notifyListeners();
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    switch (topic) {
      case node.RunChanged():
      case node.AreaChanged(area: node.ChangeArea.tasks):
        await load();
      case node.AreaChanged():
        return;
    }
  }

  @override
  Future<void> answerPersonStep({
    required RunId runId,
    required String stepName,
    required String answer,
  }) async {
    await executeNodeCommand(
      _channel,
      node.AnswerPersonStepCommand(
        runId: runId,
        stepName: stepName,
        answer: answer,
      ),
    );
    await load();
  }
}
