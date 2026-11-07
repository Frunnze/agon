import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';

import '../../../bridge/support/random_run_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';

const String gatedTaskIdPrefix = 'gated-task-';
const String gatedRunIdPrefix = 'gated-run-of-';
const String _cancelledProblem = 'the drafting run was cancelled';
const String _drafterDeviceId = 'gated-drafter-device';

enum HeldReplyTiming { answeredWhenAsked, answeredWhenReleased }

String gatedTaskId(int draftNumber) => '$gatedTaskIdPrefix$draftNumber';

final class GatedItemDraftNode implements NodeTransport {
  GatedItemDraftNode({
    required this.random,
    required this.pollsBeforeDoneByTask,
    required this.finishedStatus,
    required this.heldTaskId,
    required this.heldReplyTiming,
  });

  final Random random;
  final Map<String, int> pollsBeforeDoneByTask;
  final JsonObject finishedStatus;
  final String? heldTaskId;
  final HeldReplyTiming heldReplyTiming;
  final Map<String, int> pollCountByTask = <String, int>{};
  final Set<String> cancelledTaskIds = <String>{};
  final List<String> cancelledRunIds = <String>[];
  final List<String> deletedTaskIds = <String>[];
  final Completer<void> _release = Completer<void>();
  int draftCount = 0;
  int heldPollCount = 0;

  NodeCommandChannel get channel => NodeCommandChannel(transport: this);

  void releaseHeldReplies() => _release.complete();

  @override
  Future<String> exchange({
    required NodeEntryPoint entryPoint,
    required String inputJson,
  }) async {
    final JsonObject command = decodeObject(jsonDecode(inputJson));
    final bool isHeld =
        command['command'] == 'item_draft_status' &&
        command['task_id'] == heldTaskId;
    if (!isHeld) {
      await Future<void>.delayed(Duration.zero);
      return _answer(command);
    }

    heldPollCount += 1;
    if (heldReplyTiming == HeldReplyTiming.answeredWhenAsked) {
      final String reply = _answer(command);
      await _release.future;
      return reply;
    }
    await _release.future;
    return _answer(command);
  }

  @override
  Future<String> stop() {
    throw UnsupportedError('a gated item draft node is never stopped');
  }

  String _answer(JsonObject command) {
    final Object? name = command['command'];
    if (name == 'draft_item') {
      draftCount += 1;
      return encodeSuccessReply(<String, Object?>{
        'task_id': gatedTaskId(draftCount),
        'drafter': 'claude_code',
      });
    }
    if (name == 'item_draft_status') {
      return _answerStatus(command['task_id']! as String);
    }
    if (name == 'list_runs') {
      final String taskId = command['task_id']! as String;
      return encodeSuccessReply(<Object?>[_buildRunJson(taskId)]);
    }
    if (name == 'cancel_run') {
      final String runId = command['run_id']! as String;
      cancelledRunIds.add(runId);
      cancelledTaskIds.add(runId.substring(gatedRunIdPrefix.length));
      return encodeSuccessReply(null);
    }
    if (name == 'delete_task') {
      deletedTaskIds.add(command['task_id']! as String);
      return encodeSuccessReply(null);
    }
    return encodeErrorReply('unknown command $name');
  }

  String _answerStatus(String taskId) {
    final int pollCount = (pollCountByTask[taskId] ?? 0) + 1;
    pollCountByTask[taskId] = pollCount;
    if (cancelledTaskIds.contains(taskId)) {
      return encodeErrorReply(_cancelledProblem);
    }
    if (pollCount > (pollsBeforeDoneByTask[taskId] ?? 0)) {
      return encodeSuccessReply(finishedStatus);
    }
    return encodeSuccessReply(<String, Object?>{'state': 'working'});
  }

  JsonObject _buildRunJson(String taskId) {
    final JsonObject step = <String, Object?>{
      ...randomRunStepJson(random),
      'runner': _drafterDeviceId,
    };
    return <String, Object?>{
      ...randomRunJson(random),
      'id': '$gatedRunIdPrefix$taskId',
      'task_id': taskId,
      'number': 1,
      'steps': <Object?>[step],
    };
  }
}
