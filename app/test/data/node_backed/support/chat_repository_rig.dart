import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../../bridge/support/random_run_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';
import '../../fakes/support/workspace_inputs.dart';

const int _largestRunCount = 6;

final class RecordedRunSource extends ChangeNotifier implements RunSource {
  final Map<RunId, Run> runs = <RunId, Run>{};
  final List<RunId> refreshedRunIds = <RunId>[];

  void storeRun(Run run) {
    runs[run.id] = run;
    notifyListeners();
  }

  @override
  Run findRun(RunId runId) {
    final Run? run = runs[runId];
    if (run == null) {
      throw RecordNotFound(kind: 'run', identifier: runId.value);
    }
    return run;
  }

  @override
  Future<Run> refreshRun(RunId runId) async {
    refreshedRunIds.add(runId);
    notifyListeners();
    return findRun(runId);
  }
}

final class RecordingChatNode {
  RecordingChatNode(this.random);

  final Random random;
  final List<JsonObject> commands = <JsonObject>[];

  NodeCommandChannel get channel =>
      NodeCommandChannel(transport: ScriptedNodeTransport(answer: answer));

  String answer(String inputJson) {
    commands.add(decodeObject(jsonDecode(inputJson)));
    return encodeSuccessReply(randomChatMessageJson(random));
  }
}

typedef ChatRig = ({
  RecordedRunSource runSource,
  RecordingChatNode node,
  FakeWorkspaceRepository workspaces,
  NodeBackedChatRepository chat,
});

Run randomMappedRun(Random random) {
  return mapRunFromNode(node.Run.fromJson(randomRunJson(random)));
}

ChatRig buildChatRig(Random random) {
  final RecordedRunSource runSource = RecordedRunSource();
  for (int i = 0; i < 1 + random.nextInt(_largestRunCount); i += 1) {
    runSource.storeRun(randomMappedRun(random));
  }
  final RecordingChatNode recordingNode = RecordingChatNode(random);
  final FakeWorkspaceRepository workspaces = seedRandomWorkspaces(random)
      .repository;
  return (
    runSource: runSource,
    node: recordingNode,
    workspaces: workspaces,
    chat: NodeBackedChatRepository(
      channel: recordingNode.channel,
      runSource: runSource,
      workspaceRepository: workspaces,
    ),
  );
}
