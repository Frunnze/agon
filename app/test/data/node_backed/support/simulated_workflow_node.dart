import 'package:agent_orchestration/bridge/node/node_command_channel.dart';

import 'simulated_deletions.dart';
import 'simulated_node_replies.dart';
import 'simulated_workflow_views.dart';

const String simulatedDrafterId = 'simulated-drafter';
const String simulatedSignerId = 'simulated-signer';
const String signedState = 'signed';
const String changedState = 'changed_not_signed';
const String unsignedState = 'not_signed_yet';
const String simulatedCancelledDraftProblem = 'the drafting run was cancelled';

final class _PendingDraft {
  _PendingDraft({required this.workflow, required this.pollsLeft});

  final Map<String, Object?> workflow;
  int pollsLeft;
  bool isDone = false;
  bool isCancelled = false;
}

String _runIdOf(Object? taskId) => 'run-of-$taskId';

final class SimulatedWorkflowNode {
  SimulatedWorkflowNode({required this.pollsBeforeDraftIsDone});

  final int pollsBeforeDraftIsDone;
  final List<Map<String, Object?>> views = <Map<String, Object?>>[];
  final List<SimulatedCommand> draftCommands = <SimulatedCommand>[];
  final List<Object?> changeAgents = <Object?>[];
  final Set<String> failingCommands = <String>{};
  final List<Object?> cancelledRunIds = <Object?>[];
  final List<Object?> deletedTaskIds = <Object?>[];
  final Map<String, _PendingDraft> _drafts = <String, _PendingDraft>{};
  final Map<Object?, Map<String, Object?>> _signedWorkflows =
      <Object?, Map<String, Object?>>{};
  int draftStatusPollCount = 0;
  int _createdCount = 0;

  late final NodeCommandChannel channel = buildSimulatedChannel(answer);

  late final Map<String, SimulatedHandler> _handlers =
      <String, SimulatedHandler>{
        'list_workflows': (SimulatedCommand command) => views,
        'save_workflow': _saveWorkflow,
        'sign_workflow': _signWorkflow,
        'discard_workflow_change': _discardChange,
        'draft_workflow': _draftWorkflow,
        'change_workflow': _changeWorkflow,
        'fill_agent_settings': _fillAgentSettings,
        'workflow_draft_status': _readDraftStatus,
        'list_runs': _listRuns,
        'cancel_run': _cancelRun,
        'delete_task': _deleteTask,
        'delete_workflow': (SimulatedCommand command) =>
            deleteSimulatedWorkflow(views: views, command: command),
      };

  String answer(String inputJson) {
    return answerSimulatedCommand(
      inputJson: inputJson,
      handlers: _handlers,
      failingCommands: failingCommands,
    );
  }

  Map<String, Object?> addWorkflow({
    required String name,
    required String state,
  }) {
    final String workflowId = _nextIdentifier('workflow');
    final Map<String, Object?> workflow = <String, Object?>{
      'id': workflowId,
      'name': name,
      'availability': <String, Object?>{'kind': 'all_workspaces'},
      'agents': <Object?>[
        buildSimulatedAgentJson('$workflowId-agent', 'build'),
      ],
      'connections': <Object?>[],
      'signature': state == unsignedState ? null : simulatedSignatureJson,
    };
    final Map<String, Object?> view = buildSimulatedWorkflowView(
      workflow,
      state,
    );
    views.add(view);
    return view;
  }

  String _nextIdentifier(String kind) {
    _createdCount += 1;
    return '$kind-$_createdCount';
  }

  Map<String, Object?> _findView(Object? workflowId) {
    for (final Map<String, Object?> view in views) {
      final Map<String, Object?> workflow =
          view['workflow'] as Map<String, Object?>;
      if (workflow['id'] == workflowId) {
        return view;
      }
    }
    throw SimulatedNodeFailure('workflow $workflowId was not found');
  }

  Map<String, Object?> _storeWorkflow(Map<String, Object?> workflow) {
    final Object? workflowId = workflow['id'];
    final int index = views.indexWhere(
      (Map<String, Object?> view) =>
          (view['workflow'] as Map<String, Object?>)['id'] == workflowId,
    );
    final Map<String, Object?>? stored = index < 0
        ? null
        : views[index]['workflow'] as Map<String, Object?>;
    final Object? signature = stored?['signature'];
    final bool isSignedNow =
        index >= 0 && views[index]['signature_state'] == signedState;
    if (stored != null && isSignedNow) {
      _signedWorkflows[workflowId] = stored;
    }
    final Map<String, Object?> kept = <String, Object?>{
      ...workflow,
      'signature': signature,
    };
    final Map<String, Object?> view = buildSimulatedWorkflowView(
      kept,
      signature == null ? unsignedState : changedState,
    );
    if (index < 0) {
      views.add(view);
    } else {
      views[index] = view;
    }
    return view;
  }

  Object? _saveWorkflow(SimulatedCommand command) {
    final Map<String, Object?> workflow =
        command['workflow'] as Map<String, Object?>;
    _findView(workflow['id']);
    return _storeWorkflow(workflow);
  }

  Object? _signWorkflow(SimulatedCommand command) {
    _signedWorkflows.remove(command['workflow_id']);
    return _replaceState(command['workflow_id'], signedState);
  }

  Object? _discardChange(SimulatedCommand command) {
    final Object? workflowId = command['workflow_id'];
    final Map<String, Object?>? signedWorkflow = _signedWorkflows.remove(
      workflowId,
    );
    if (signedWorkflow != null) {
      final Map<String, Object?> view = _findView(workflowId);
      views[views.indexOf(view)] = buildSimulatedWorkflowView(
        signedWorkflow,
        signedState,
      );
    }
    return _replaceState(workflowId, signedState);
  }

  Map<String, Object?> _replaceState(Object? workflowId, String state) {
    final Map<String, Object?> view = _findView(workflowId);
    final Map<String, Object?> signed = <String, Object?>{
      ...view['workflow'] as Map<String, Object?>,
      'signature': simulatedSignatureJson,
    };
    final Map<String, Object?> replaced = buildSimulatedWorkflowView(
      signed,
      state,
    );
    views[views.indexOf(view)] = replaced;
    return replaced;
  }

  Object? _draftWorkflow(SimulatedCommand command) {
    draftCommands.add(command);
    final String workflowId = _nextIdentifier('drafted');
    final Map<String, Object?> workflow = <String, Object?>{
      'id': workflowId,
      'name': workflowId,
      'availability': <String, Object?>{
        'kind': 'only_workspaces',
        'workspaces': <Object?>[command['workspace_id']],
      },
      'agents': <Object?>[buildSimulatedAgentJson('$workflowId-plan', 'plan')],
      'connections': <Object?>[],
      'signature': null,
    };
    return _queueDraft(workflow);
  }

  Object? _changeWorkflow(SimulatedCommand command) {
    final Object? agent = command['agent'];
    if (agent is! String) {
      throw StateError('change_workflow needs an agent');
    }
    changeAgents.add(agent);
    final Map<String, Object?> workflow = <String, Object?>{
      ..._findView(command['workflow_id'])['workflow'] as Map<String, Object?>,
    };
    final List<Object?> agents = workflow['agents'] as List<Object?>;
    workflow['agents'] = <Object?>[
      ...agents,
      buildSimulatedAgentJson(_nextIdentifier('requested'), 'requested'),
    ];
    return _queueDraft(workflow);
  }

  Object? _fillAgentSettings(SimulatedCommand command) {
    final Map<String, Object?> workflow = <String, Object?>{
      ..._findView(command['workflow_id'])['workflow'] as Map<String, Object?>,
    };
    workflow['agents'] = <Object?>[
      for (final Object? agent in workflow['agents'] as List<Object?>)
        fillSimulatedAgent(agent as Map<String, Object?>, command['agent_id']),
    ];
    return _queueDraft(workflow);
  }

  Map<String, Object?> _queueDraft(Map<String, Object?> workflow) {
    final String taskId = _nextIdentifier('task');
    _drafts[taskId] = _PendingDraft(
      workflow: workflow,
      pollsLeft: pollsBeforeDraftIsDone,
    );
    return <String, Object?>{
      'workflow_id': workflow['id'],
      'task_id': taskId,
      'drafter': 'claude_code',
    };
  }

  Object? _readDraftStatus(SimulatedCommand command) {
    draftStatusPollCount += 1;
    final _PendingDraft? draft = _drafts[command['task_id']];
    if (draft == null) {
      throw SimulatedNodeFailure('task ${command['task_id']} was not found');
    }
    if (draft.isCancelled) {
      throw const SimulatedNodeFailure(simulatedCancelledDraftProblem);
    }
    if (draft.pollsLeft > 0) {
      draft.pollsLeft -= 1;
      return <String, Object?>{'state': 'working'};
    }
    draft.isDone = true;
    _drafts.remove(command['task_id']);
    return <String, Object?>{
      'state': 'done',
      'workflow': _storeWorkflow(draft.workflow),
    };
  }

  Object? _cancelRun(SimulatedCommand command) {
    final Object? runId = command['run_id'];
    for (final MapEntry<String, _PendingDraft> entry in _drafts.entries) {
      final _PendingDraft draft = entry.value;
      if (_runIdOf(entry.key) != runId) {
        continue;
      }
      if (draft.isDone || draft.isCancelled) {
        throw const SimulatedNodeFailure('the run has already finished');
      }
      draft.isCancelled = true;
      cancelledRunIds.add(runId);
      return null;
    }
    throw SimulatedNodeFailure('run $runId was not found');
  }

  Object? _deleteTask(SimulatedCommand command) {
    final Object? taskId = command['task_id'];
    final _PendingDraft? removed = _drafts.remove(taskId);
    if (removed == null) {
      throw SimulatedNodeFailure('task $taskId was not found');
    }
    deletedTaskIds.add(taskId);
    return null;
  }

  Object? _listRuns(SimulatedCommand command) {
    if (!_drafts.containsKey(command['task_id'])) {
      return <Object?>[];
    }
    return <Object?>[
      <String, Object?>{
        'id': _runIdOf(command['task_id']),
        'task_id': command['task_id'],
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
      },
    ];
  }
}
