import 'dart:convert';
import 'dart:io';

import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import 'live_run_views.dart';

const String _sharedCasesPath =
    '../rust/crates/orchestration-server/tests/fixtures/'
    'live_run_event_cases.json';

final class PostedRunEvent {
  const PostedRunEvent({
    required this.postedAt,
    required this.event,
    required this.isAccepted,
  });

  final DateTime postedAt;
  final node.RunEvent event;
  final bool isAccepted;
}

final class SharedLiveRunCase {
  const SharedLiveRunCase({
    required this.initialRun,
    required this.events,
    required this.expectedRun,
  });

  final Run initialRun;
  final List<PostedRunEvent> events;
  final Run expectedRun;
}

Map<String, Object?> _readObject(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw FormatException('a shared live run entry is not an object: $entry');
  }
  return entry;
}

List<Object?> _readList(Object? entry) {
  if (entry is! List<Object?>) {
    throw FormatException('a shared live run entry is not a list: $entry');
  }
  return entry;
}

PostedRunEvent _readPostedEvent(Object? entry) {
  final Map<String, Object?> fields = _readObject(entry);
  return PostedRunEvent(
    postedAt: decodeMoment(fields['posted_at']),
    event: node.RunEvent.fromJson(fields['event']),
    isAccepted: fields['is_accepted']! as bool,
  );
}

Run _readRun(Object? entry) {
  return mapRunFromNode(node.Run.fromJson(entry));
}

SharedLiveRunCase _readCase(Object? entry) {
  final Map<String, Object?> fields = _readObject(entry);
  return SharedLiveRunCase(
    initialRun: _readRun(fields['initial_run']),
    events: <PostedRunEvent>[
      for (final Object? posted in _readList(fields['events']))
        _readPostedEvent(posted),
    ],
    expectedRun: _readRun(fields['expected_run']),
  );
}

List<SharedLiveRunCase> readSharedLiveRunCases() {
  final String sharedText = File(_sharedCasesPath).readAsStringSync();
  final Map<String, Object?> table = _readObject(jsonDecode(sharedText));
  return <SharedLiveRunCase>[
    for (final Object? entry in _readList(table['cases'])) _readCase(entry),
  ];
}

ShownRecord describeRunProgress(Run run) {
  final RunFailure? failure = run.failure;
  return <Object?>[
    run.status,
    run.finishedAt,
    <ShownRecord>[
      for (final RunStep step in run.steps)
        <Object?>[step.status, ...describeStepBesidesStatus(step)],
    ],
    if (failure != null)
      <Object?>[
        failure.stepName,
        failure.runner,
        failure.reason,
        failure.retryRunsOnSameRunner,
      ],
  ];
}

ShownRecord describeWholeRun(Run run) {
  return <Object?>[
    run.id,
    run.taskId,
    run.number,
    run.link,
    run.linkLostAt,
    run.agentSession,
    run.worktreeBranch,
    run.startedBy,
    run.startedAt,
    describeRunProgress(run),
    describeLog(run.log),
    describeChat(run.chat),
    run.loopRounds.length,
    run.notes.length,
  ];
}

node.WatchView buildViewKeepingLink(Run run, List<node.RunEvent> events) {
  return node.WatchView(
    link: node.RunnerLink.values.byName(run.link.name),
    linkLostAt: run.linkLostAt,
    problem: null,
    events: events,
  );
}
