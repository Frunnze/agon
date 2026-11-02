import 'dart:math';

import '../../support/random_inputs.dart';
import 'node_json_primitives.dart';
import 'node_wire_names.dart';
import 'random_catalog_json.dart';

const int _hoursPerDay = 24;
const int _minutesPerHour = 60;

Map<String, Object?> randomCanvasPositionJson(Random random) {
  return <String, Object?>{
    'horizontal': randomCanvasCoordinate(random),
    'vertical': randomCanvasCoordinate(random),
  };
}

Map<String, Object?> randomWorkflowAgentJson(Random random) {
  return <String, Object?>{
    'id': randomUuidText(random),
    'name': randomText(random),
    'kind': randomOptional(random, _randomAgentKindName),
    'task': randomText(random),
    'runs_on': randomRunnerTargetJson(random),
    'skills': randomUuidTexts(random),
    'uses_automatic_skills': random.nextBool(),
    'approval_policy': pickOne(random, nodeApprovalPolicies),
    'position': randomCanvasPositionJson(random),
  };
}

Map<String, Object?> randomAgentConnectionJson(Random random) {
  return <String, Object?>{
    'from': randomUuidText(random),
    'to': randomUuidText(random),
  };
}

Map<String, Object?> randomWorkflowSignatureJson(Random random) {
  return <String, Object?>{
    'signed_by': randomDeviceIdText(random),
    'signature': randomBytes(random),
    'signed_document': randomText(random),
  };
}

Map<String, Object?> randomWorkflowJson(Random random) {
  return <String, Object?>{
    'id': randomUuidText(random),
    'name': randomText(random),
    'availability': randomWorkspaceScopeJson(random),
    'agents': randomListOf(random, randomWorkflowAgentJson),
    'connections': randomListOf(random, randomAgentConnectionJson),
    'signature': randomOptional(random, randomWorkflowSignatureJson),
  };
}

Map<String, Object?> randomDiffLineJson(Random random) {
  return <String, Object?>{
    pickOne(random, nodeDiffChanges): randomText(random),
  };
}

Map<String, Object?> randomWorkflowViewJson(Random random) {
  return <String, Object?>{
    'workflow': randomWorkflowJson(random),
    'agent_names': randomTexts(random),
    'document': randomText(random),
    'signature_state': pickOne(random, nodeSignatureStates),
    'changes': randomListOf(random, randomDiffLineJson),
    'signed_at': randomOptional(random, randomMomentText),
    'changed_at': randomOptional(random, randomMomentText),
    'changed_by': randomOptional(random, randomDeviceIdText),
    'changed_by_name': randomOptional(random, randomText),
  };
}

Map<String, Object?> randomDraftStatusJson(Random random) {
  final List<Map<String, Object?>> states = <Map<String, Object?>>[
    <String, Object?>{'state': 'working'},
    <String, Object?>{
      'state': 'done',
      'workflow': randomWorkflowViewJson(random),
    },
  ];
  return pickOne(random, states);
}

Map<String, Object?> randomTaskDoerJson(Random random) {
  final List<Map<String, Object?>> doers = <Map<String, Object?>>[
    <String, Object?>{
      'kind': 'one_agent',
      'agent': pickOne(random, nodeAgentKinds),
    },
    <String, Object?>{
      'kind': 'workflow',
      'workflow_id': randomUuidText(random),
    },
  ];
  return pickOne(random, doers);
}

Map<String, Object?> randomScheduleTimeJson(Random random) {
  return <String, Object?>{
    'hour': random.nextInt(_hoursPerDay),
    'minute': random.nextInt(_minutesPerHour),
  };
}

Map<String, Object?> randomScheduleJson(Random random) {
  final List<Map<String, Object?>> schedules = <Map<String, Object?>>[
    <String, Object?>{
      'every': 'hour',
      'minute': random.nextInt(_minutesPerHour),
    },
    <String, Object?>{'every': 'day', 'at': randomScheduleTimeJson(random)},
    <String, Object?>{
      'every': 'week',
      'on': pickOne(random, nodeWeekdays),
      'at': randomScheduleTimeJson(random),
    },
  ];
  return pickOne(random, schedules);
}

Map<String, Object?> randomTaskJson(Random random) {
  return <String, Object?>{
    'id': randomUuidText(random),
    'title': randomText(random),
    'details': randomText(random),
    'project_id': randomUuidText(random),
    'doer': randomTaskDoerJson(random),
    'runs_on': randomRunnerTargetJson(random),
    'skills': randomUuidTexts(random),
    'uses_automatic_skills': random.nextBool(),
    'approval_policy': pickOne(random, nodeApprovalPolicies),
    'schedule': randomOptional(random, randomScheduleJson),
    'status': pickOne(random, nodeTaskStatuses),
    'created_at': randomMomentText(random),
  };
}

Map<String, Object?> randomTaskSummaryJson(Random random) {
  return <String, Object?>{
    'to_do': randomCount(random),
    'running': randomCount(random),
    'waiting_for_approval': randomCount(random),
    'failed': randomCount(random),
    'done': randomCount(random),
  };
}

Map<String, Object?> randomWorkflowAgentTaskJson(Random random) {
  return <String, Object?>{
    'workflow_id': randomUuidText(random),
    'task_id': randomUuidText(random),
    'drafter': pickOne(random, nodeAgentKinds),
  };
}

String _randomAgentKindName(Random random) {
  return pickOne(random, nodeAgentKinds);
}
