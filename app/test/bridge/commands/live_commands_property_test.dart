import 'dart:math';

import 'package:agent_orchestration/bridge/commands/live_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../support/hostile_texts.dart';
import '../support/random_live_json.dart';
import '../support/simple_command_properties.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/library_and_live_reply_properties.dart';

const int _firstMemberSeed = 8630000;
const int _firstReplySeed = 8631000;
const int _nothingReplySeed = 8632000;

const List<ModelledCommandRow> _liveCommandRows = <ModelledCommandRow>[
  ModelledCommandRow(
    typeName: 'watch_run_command',
    commandName: 'watch_run',
    build: _buildWatchRun,
  ),
  ModelledCommandRow(
    typeName: 'stop_watching_run_command',
    commandName: 'stop_watching_run',
    build: _buildStopWatchingRun,
  ),
];

const List<ReplyRow> _watchReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'watch_run_command',
    commandName: 'watch_run',
    buildObjectJson: randomWatchViewJson,
    requiredFields: <String>['link', 'events'],
  ),
];

void main() {
  testModelledCommandRows(_liveCommandRows, _firstMemberSeed);
  testObjectReplyRows(_watchReplyRows, _firstReplySeed);
  testNothingReplyProperties(
    typeName: 'stop_watching_run_command',
    seed: _nothingReplySeed,
    buildCommand: findCommandShape('stop_watching_run').buildCommand,
  );
}

ModelledCommand _buildWatchRun(Random random) {
  final RunId runId = RunId(randomHostileText(random));
  final WatchRunCommand command = WatchRunCommand(runId: runId);
  return (
    command: command,
    givenFields: <Object?>[runId],
    keptFields: <Object?>[command.runId],
    expectedArguments: <String, Object?>{'run_id': runId.value},
  );
}

ModelledCommand _buildStopWatchingRun(Random random) {
  final RunId runId = RunId(randomHostileText(random));
  final StopWatchingRunCommand command = StopWatchingRunCommand(runId: runId);
  return (
    command: command,
    givenFields: <Object?>[runId],
    keptFields: <Object?>[command.runId],
    expectedArguments: <String, Object?>{'run_id': runId.value},
  );
}
