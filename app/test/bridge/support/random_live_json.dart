import 'dart:math';

import '../../support/random_inputs.dart';
import 'node_json_primitives.dart';
import 'node_wire_names.dart';
import 'random_run_json.dart';

Map<String, Object?> randomRunEventJson(Random random) {
  final List<Map<String, Object?>> events = <Map<String, Object?>>[
    <String, Object?>{
      'kind': 'step_status_changed',
      'step_name': randomText(random),
      'status': pickOne(random, nodeStepStatuses),
    },
    <String, Object?>{
      'kind': 'log_appended',
      'line': randomLogLineJson(random),
    },
    <String, Object?>{
      'kind': 'chat_appended',
      'message': randomChatMessageJson(random),
    },
    <String, Object?>{
      'kind': 'session_started',
      'session': randomText(random),
    },
    <String, Object?>{
      'kind': 'worktree_created',
      'branch': randomText(random),
    },
    <String, Object?>{
      'kind': 'link_changed',
      'link': pickOne(random, nodeRunnerLinks),
    },
    <String, Object?>{
      'kind': 'failed',
      'failure': randomRunFailureJson(random),
    },
    <String, Object?>{
      'kind': 'step_result_recorded',
      'step_name': randomText(random),
      'result': randomText(random),
    },
    <String, Object?>{'kind': 'finished'},
  ];
  return pickOne(random, events);
}

Map<String, Object?> randomWatchViewJson(Random random) {
  return <String, Object?>{
    'link': pickOne(random, nodeRunnerLinks),
    'link_lost_at': randomOptional(random, randomMomentText),
    'problem': randomOptional(random, randomText),
    'events': randomListOf(random, randomRunEventJson),
  };
}
