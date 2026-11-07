import 'simulated_node_replies.dart';
import 'simulated_workflow_node.dart';

const Map<String, Object?> simulatedSignatureJson = <String, Object?>{
  'signed_by': simulatedSignerId,
  'signature': <int>[7, 7],
  'signed_document': 'sealed document',
};

const String simulatedChangerId = 'simulated-changer';

Map<String, Object?> buildSimulatedWorkflowView(
  Map<String, Object?> workflow,
  String state,
) {
  final List<Object?> changes = state == changedState
      ? <Object?>[
          <String, Object?>{'unchanged': 'name: ${workflow['name']}'},
          <String, Object?>{'removed': 'steps: old'},
          <String, Object?>{'added': 'steps: new'},
        ]
      : <Object?>[];
  return <String, Object?>{
    'workflow': workflow,
    'agent_names': <Object?>[
      for (final Object? agent in workflow['agents'] as List<Object?>)
        (agent as Map<String, Object?>)['name'],
    ],
    'document': 'name: ${workflow['name']}\nsteps: new\n',
    'signature_state': state,
    'changes': changes,
    'signed_at': workflow['signature'] == null ? null : simulatedMoment,
    'changed_at': state == changedState ? simulatedMoment : null,
    'changed_by': state == changedState ? simulatedChangerId : null,
    'changed_by_name': null,
  };
}

Map<String, Object?> fillSimulatedAgent(
  Map<String, Object?> agent,
  Object? agentId,
) {
  if (agent['id'] != agentId) {
    return agent;
  }
  return <String, Object?>{...agent, 'kind': 'codex', 'task': 'Filled'};
}

Map<String, Object?> buildSimulatedAgentJson(String agentId, String name) {
  return <String, Object?>{
    'id': agentId,
    'name': name,
    'kind': null,
    'task': '',
    'runs_on': <String, Object?>{'kind': 'any_free_runner'},
    'skills': <Object?>[],
    'uses_automatic_skills': false,
    'approval_policy': 'ask_before_risky_actions',
    'position': <String, Object?>{'horizontal': 10.5, 'vertical': 20.5},
  };
}

bool isSimulatedWorkflowAvailableIn(
  Map<String, Object?> view,
  Object? workspaceId,
) {
  final Map<String, Object?> workflow =
      view['workflow']! as Map<String, Object?>;
  final Map<String, Object?> availability =
      workflow['availability']! as Map<String, Object?>;
  if (availability['kind'] == 'all_workspaces') {
    return true;
  }
  final List<Object?> listed = availability['workspaces']! as List<Object?>;
  return listed.contains(workspaceId);
}

Map<String, Object?> buildSimulatedDraftRunJson(Object? taskId, String runId) {
  return <String, Object?>{
    'id': runId,
    'task_id': taskId,
    'number': 1,
    'status': 'running',
    'steps': <Object?>[
      <String, Object?>{
        'name': 'Claude Code',
        'agent_id': null,
        'runner': simulatedDrafterId,
        'status': 'running',
        'started_at': simulatedMoment,
        'finished_at': null,
        'result': null,
      },
    ],
    'log': <Object?>[],
    'chat': <Object?>[],
    'failure': null,
    'link': 'direct',
    'agent_session': null,
    'worktree_branch': null,
    'started_by': simulatedDrafterId,
    'started_at': simulatedMoment,
    'finished_at': null,
  };
}

Map<String, Object?> buildSeededWorkflowJson({
  required String workflowId,
  required String name,
  required String state,
}) {
  return <String, Object?>{
    'id': workflowId,
    'name': name,
    'availability': <String, Object?>{'kind': 'all_workspaces'},
    'agents': <Object?>[buildSimulatedAgentJson('$workflowId-agent', 'build')],
    'connections': <Object?>[],
    'signature': state == unsignedState ? null : simulatedSignatureJson,
  };
}
