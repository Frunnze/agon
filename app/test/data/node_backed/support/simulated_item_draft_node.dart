import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';

import '../../../bridge/support/random_run_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';
import 'node_backed_harness.dart';

const String simulatedDraftingTaskId = 'drafting-task';
const String simulatedDraftingRunId = 'drafting-run';
const String simulatedDrafterDeviceId = 'drafter-device';
const String _cancelledProblem =
    'the drafting run did not finish: the drafting run was cancelled';

final class SimulatedItemDraftNode {
  SimulatedItemDraftNode({
    required this.random,
    required this.pollsBeforeDone,
    required this.finishedStatus,
  });

  final Random random;
  final int pollsBeforeDone;
  final JsonObject finishedStatus;
  final List<JsonObject> commands = <JsonObject>[];
  final List<String> cancelledRunIds = <String>[];
  final List<String> deletedTaskIds = <String>[];
  int statusPollCount = 0;

  NodeCommandChannel get channel => buildSimulatedChannel(answer);

  List<JsonObject> commandsNamed(String name) {
    return <JsonObject>[
      for (final JsonObject command in commands)
        if (command['command'] == name) command,
    ];
  }

  String answer(String inputJson) {
    final JsonObject command = decodeObject(jsonDecode(inputJson));
    commands.add(command);
    final Object? name = command['command'];
    if (name == 'draft_item') {
      return encodeSuccessReply(<String, Object?>{
        'task_id': simulatedDraftingTaskId,
        'drafter': 'claude_code',
      });
    }
    if (name == 'item_draft_status') {
      return _answerStatus();
    }
    if (name == 'list_runs') {
      return encodeSuccessReply(<Object?>[_buildRunJson()]);
    }
    if (name == 'cancel_run') {
      cancelledRunIds.add(command['run_id']! as String);
      return encodeSuccessReply(null);
    }
    if (name == 'delete_task') {
      deletedTaskIds.add(command['task_id']! as String);
      return encodeSuccessReply(null);
    }
    return encodeErrorReply('unknown command $name');
  }

  String _answerStatus() {
    if (cancelledRunIds.isNotEmpty) {
      return encodeErrorReply(_cancelledProblem);
    }
    statusPollCount += 1;
    if (statusPollCount > pollsBeforeDone) {
      return encodeSuccessReply(finishedStatus);
    }
    return encodeSuccessReply(<String, Object?>{'state': 'working'});
  }

  JsonObject _buildRunJson() {
    final JsonObject step = <String, Object?>{
      ...randomRunStepJson(random),
      'runner': simulatedDrafterDeviceId,
    };
    return <String, Object?>{
      ...randomRunJson(random),
      'id': simulatedDraftingRunId,
      'task_id': simulatedDraftingTaskId,
      'number': 1,
      'steps': <Object?>[step],
    };
  }
}
