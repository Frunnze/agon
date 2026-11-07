import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/live_run_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';

import '../../support/random_live_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> liveRunConstructorRows = <ConstructorRow>[
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'run_event',
      buildJson: randomRunEventJson,
      decode: RunEvent.fromJson,
    ),
    rebuild: _rebuildRunEvent,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'step_status_changed',
      buildJson: randomStepStatusChangedJson,
      decode: RunEvent.fromJson,
    ),
    rebuild: _rebuildRunEvent,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'log_appended',
      buildJson: randomLogAppendedJson,
      decode: RunEvent.fromJson,
    ),
    rebuild: _rebuildRunEvent,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'chat_appended',
      buildJson: randomChatAppendedJson,
      decode: RunEvent.fromJson,
    ),
    rebuild: _rebuildRunEvent,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'session_started',
      buildJson: randomSessionStartedJson,
      decode: RunEvent.fromJson,
    ),
    rebuild: _rebuildRunEvent,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'worktree_created',
      buildJson: randomWorktreeCreatedJson,
      decode: RunEvent.fromJson,
    ),
    rebuild: _rebuildRunEvent,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'link_changed',
      buildJson: randomLinkChangedJson,
      decode: RunEvent.fromJson,
    ),
    rebuild: _rebuildRunEvent,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'run_failed',
      buildJson: randomRunFailedJson,
      decode: RunEvent.fromJson,
    ),
    rebuild: _rebuildRunEvent,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'step_result_recorded',
      buildJson: randomStepResultRecordedJson,
      decode: RunEvent.fromJson,
    ),
    rebuild: _rebuildRunEvent,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'run_finished',
      buildJson: randomRunFinishedJson,
      decode: RunEvent.fromJson,
    ),
    rebuild: _rebuildRunEvent,
  ),
];

const List<EncodableRow> liveRunEncodableRows = <EncodableRow>[
  EncodableRow(
    typeName: 'watch_view',
    buildJson: randomWatchViewJson,
    decode: WatchView.fromJson,
  ),
];

Object? randomStepStatusChangedJson(Random random) {
  return _randomRunEventJsonOfKind<StepStatusChanged>(random);
}

Object? randomLogAppendedJson(Random random) {
  return _randomRunEventJsonOfKind<LogAppended>(random);
}

Object? randomChatAppendedJson(Random random) {
  return _randomRunEventJsonOfKind<ChatAppended>(random);
}

Object? randomSessionStartedJson(Random random) {
  return _randomRunEventJsonOfKind<SessionStarted>(random);
}

Object? randomWorktreeCreatedJson(Random random) {
  return _randomRunEventJsonOfKind<WorktreeCreated>(random);
}

Object? randomLinkChangedJson(Random random) {
  return _randomRunEventJsonOfKind<LinkChanged>(random);
}

Object? randomRunFailedJson(Random random) {
  return _randomRunEventJsonOfKind<RunFailed>(random);
}

Object? randomStepResultRecordedJson(Random random) {
  return _randomRunEventJsonOfKind<StepResultRecorded>(random);
}

Object? randomRunFinishedJson(Random random) {
  return _randomRunEventJsonOfKind<RunFinished>(random);
}

Object? _randomRunEventJsonOfKind<Kind extends RunEvent>(Random random) {
  return randomJsonOfKind<Kind>(
    random: random,
    buildJson: randomRunEventJson,
    decode: RunEvent.fromJson,
  );
}

JsonEncodable _rebuildRunEvent(JsonEncodable value) {
  final RunEvent event = value as RunEvent;
  return switch (event) {
    StepStatusChanged(:final String stepName, :final StepStatus status) =>
      StepStatusChanged(stepName: stepName, status: status),
    LogAppended(:final LogLine line) => LogAppended(line: line),
    ChatAppended(:final ChatMessage message) => ChatAppended(message: message),
    SessionStarted(:final String session) => SessionStarted(session: session),
    WorktreeCreated(:final String branch) => WorktreeCreated(branch: branch),
    LinkChanged(:final RunnerLink link) => LinkChanged(link: link),
    RunFailed(:final RunFailure failure) => RunFailed(failure: failure),
    StepResultRecorded(
      :final String stepName,
      :final String result,
      :final String? outcome,
    ) =>
      StepResultRecorded(stepName: stepName, result: result, outcome: outcome),
    RunFinished() => const RunFinished(),
  };
}
