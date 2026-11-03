import 'dart:math';

import '../../support/random_inputs.dart';
import 'node_json_primitives.dart';
import 'node_wire_names.dart';
import 'random_branching_json.dart';
import 'random_work_json.dart';

Map<String, Object?> randomRunStepJson(Random random) {
  return <String, Object?>{
    'name': randomText(random),
    'agent_id': randomOptional(random, randomUuidText),
    'runner': randomOptional(random, randomDeviceIdText),
    'status': pickOne(random, nodeStepStatuses),
    'started_at': randomOptional(random, randomMomentText),
    'finished_at': randomOptional(random, randomMomentText),
    'result': randomOptional(random, randomText),
    'outcome': randomOptional(random, randomText),
    'loop_source': randomOptional(random, randomText),
    'earlier_rounds': randomListOf(random, randomEarlierRoundJson),
  };
}

Map<String, Object?> randomLogLineJson(Random random) {
  return <String, Object?>{
    'at': randomMomentText(random),
    'step_name': randomText(random),
    'text': randomText(random),
    'is_error': random.nextBool(),
  };
}

Map<String, Object?> randomChatMessageJson(Random random) {
  return <String, Object?>{
    'at': randomMomentText(random),
    'author': pickOne(random, nodeChatAuthors),
    'text': randomText(random),
    'is_error': random.nextBool(),
    'waiting_to_send': random.nextBool(),
  };
}

Map<String, Object?> randomRunFailureJson(Random random) {
  return <String, Object?>{
    'step_name': randomText(random),
    'runner': randomOptional(random, randomDeviceIdText),
    'reason': randomText(random),
    'retry_runs_on_same_runner': random.nextBool(),
  };
}

Map<String, Object?> randomRunJson(Random random) {
  return <String, Object?>{
    'id': randomUuidText(random),
    'task_id': randomUuidText(random),
    'number': randomCount(random),
    'status': pickOne(random, nodeRunStatuses),
    'steps': randomListOf(random, randomRunStepJson),
    'log': randomListOf(random, randomLogLineJson),
    'chat': randomListOf(random, randomChatMessageJson),
    'failure': randomOptional(random, randomRunFailureJson),
    'link': pickOne(random, nodeRunnerLinks),
    'link_lost_at': randomOptional(random, randomMomentText),
    'agent_session': randomOptional(random, randomText),
    'worktree_branch': randomOptional(random, randomText),
    'started_by': randomDeviceIdText(random),
    'started_at': randomMomentText(random),
    'finished_at': randomOptional(random, randomMomentText),
    'loop_rounds': randomListOf(random, randomLoopRoundsJson),
    'notes': randomListOf(random, randomRunNoteJson),
  };
}

Map<String, Object?> randomCurrentStepJson(Random random) {
  return <String, Object?>{
    'number': randomCount(random),
    'name': randomText(random),
    'runner': randomOptional(random, randomDeviceIdText),
    'status': pickOne(random, nodeStepStatuses),
  };
}

Map<String, Object?> randomRunProgressJson(Random random) {
  return <String, Object?>{
    'run_id': randomUuidText(random),
    'number': randomCount(random),
    'status': pickOne(random, nodeRunStatuses),
    'link': pickOne(random, nodeRunnerLinks),
    'started_at': randomMomentText(random),
    'finished_at': randomOptional(random, randomMomentText),
    'step_count': randomCount(random),
    'current_step': randomOptional(random, randomCurrentStepJson),
  };
}

Map<String, Object?> randomRunViewJson(Random random) {
  return <String, Object?>{
    'run': randomRunJson(random),
    'progress': randomRunProgressJson(random),
    'link': pickOne(random, nodeRunnerLinks),
    'link_lost_at': randomOptional(random, randomMomentText),
  };
}

Map<String, Object?> randomTaskViewJson(Random random) {
  return <String, Object?>{
    'task': randomTaskJson(random),
    'project_name': randomText(random),
    'latest_run': randomOptional(random, randomRunProgressJson),
  };
}

Map<String, Object?> randomTasksViewJson(Random random) {
  return <String, Object?>{
    'summary': randomTaskSummaryJson(random),
    'summary_text': randomText(random),
    'tasks': randomListOf(random, randomTaskViewJson),
  };
}

Map<String, Object?> randomJobViewJson(Random random) {
  return <String, Object?>{
    'task': randomTaskJson(random),
    'project_name': randomText(random),
    'schedule_description': randomText(random),
    'next_run_at': randomMomentText(random),
    'latest_run': randomOptional(random, randomRunProgressJson),
  };
}

Map<String, Object?> randomRunCommandJson(Random random) {
  return <String, Object?>{
    'kind': 'run_command',
    'tool': randomText(random),
    'command': randomText(random),
  };
}

Map<String, Object?> randomApprovalActionJson(Random random) {
  final List<Map<String, Object?>> actions = <Map<String, Object?>>[
    <String, Object?>{
      'kind': 'push_commits',
      'repository': randomText(random),
      'branch': randomText(random),
      'commits': randomTexts(random),
    },
    <String, Object?>{'kind': 'deploy', 'target': randomText(random)},
    <String, Object?>{
      'kind': 'delete_branch_or_files',
      'repository': randomText(random),
      'what': randomText(random),
    },
    <String, Object?>{
      'kind': 'sign_workflow',
      'workflow_id': randomUuidText(random),
    },
    randomRunCommandJson(random),
    randomImproveSkillJson(random),
  ];
  return pickOne(random, actions);
}

Map<String, Object?> randomImproveSkillJson(Random random) {
  return <String, Object?>{
    'kind': 'improve_skill',
    'skill_id': randomUuidText(random),
    'summary': randomText(random),
    'proposed_instructions': randomText(random),
  };
}

Map<String, Object?> randomSkillChangeViewJson(Random random) {
  return <String, Object?>{
    'skill_name': randomText(random),
    'changes': randomListOf(random, randomDiffLineJson),
  };
}

Map<String, Object?> randomSignedDecisionJson(Random random) {
  return <String, Object?>{
    'decision': pickOne(random, nodeApprovalDecisions),
    'decided_by': randomDeviceIdText(random),
    'decided_at': randomMomentText(random),
    'signature': randomBytes(random),
  };
}

Map<String, Object?> randomApprovalRequestJson(Random random) {
  return <String, Object?>{
    'id': randomUuidText(random),
    'run_id': randomOptional(random, randomUuidText),
    'action': randomApprovalActionJson(random),
    'requested_by': randomDeviceIdText(random),
    'requested_at': randomMomentText(random),
    'decision': randomOptional(random, randomSignedDecisionJson),
  };
}

Map<String, Object?> randomApprovalViewJson(Random random) {
  return <String, Object?>{
    'approval': randomApprovalRequestJson(random),
    'description': randomText(random),
    'is_waiting': random.nextBool(),
    'skill_change': randomOptional(random, randomSkillChangeViewJson),
  };
}

Map<String, Object?> randomApprovalsViewJson(Random random) {
  return <String, Object?>{
    'waiting_count': randomCount(random),
    'approvals': randomListOf(random, randomApprovalViewJson),
  };
}
