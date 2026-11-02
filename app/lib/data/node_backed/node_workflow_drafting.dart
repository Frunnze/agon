import 'package:agent_orchestration/bridge/codecs/drafting_task_views.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/deletion_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/drafting_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/node_command.dart' as node;
import 'package:agent_orchestration/bridge/commands/run_commands.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed.dart';

typedef DraftedWorkflowStore = Workflow Function(node.WorkflowView drafted);

typedef WorkflowAgentCommand = node.NodeCommand<node.WorkflowAgentTaskView>;

final class _RunningDraft {
  const _RunningDraft(this.start);

  final Future<node.WorkflowAgentTaskView> start;
}

final class NodeWorkflowDrafting {
  NodeWorkflowDrafting({
    required NodeCommandChannel channel,
    required Duration pollInterval,
  }) : _channel = channel,
       _pollInterval = pollInterval;

  final NodeCommandChannel _channel;
  final Duration _pollInterval;
  final Map<WorkflowDraft, _RunningDraft> _runningDrafts =
      <WorkflowDraft, _RunningDraft>{};

  Stream<WorkflowDraftProgress> streamDraftProgress({
    required WorkflowDraft draft,
    required node.DraftWorkflowCommand command,
    required DraftedWorkflowStore storeDrafted,
  }) async* {
    if (_runningDrafts.containsKey(draft)) {
      throw StateError('This workflow is already being drafted');
    }

    final _RunningDraft running = _RunningDraft(
      executeNodeCommand(_channel, command),
    );
    _runningDrafts[draft] = running;
    try {
      final node.WorkflowAgentTaskView started = await running.start;
      yield* _pollDraftProgress(
        draft: draft,
        workspaceId: command.workspaceId,
        started: started,
        storeDrafted: storeDrafted,
      );
    } finally {
      _runningDrafts.remove(draft);
    }
  }

  Future<void> stopDrafting(WorkflowDraft draft) async {
    final _RunningDraft? running = _runningDrafts[draft];
    if (running == null) {
      throw StateError('No workflow is being drafted from these words');
    }

    final node.WorkflowAgentTaskView started = await running.start;
    final List<node.Run> runs = await executeNodeCommand(
      _channel,
      node.ListRunsCommand(taskId: started.taskId),
    );
    final node.Run? draftingRun = findLatestRun(runs);
    if (draftingRun == null) {
      throw StateError('The workflow draft has no run to stop');
    }

    await executeNodeCommand(
      _channel,
      node.CancelRunCommand(runId: draftingRun.id),
    );
    _runningDrafts.remove(draft);
    await executeNodeCommand(
      _channel,
      node.DeleteTaskCommand(taskId: started.taskId),
    );
  }

  Future<node.WorkflowView> redraftWorkflow({
    required WorkspaceId workspaceId,
    required WorkflowAgentCommand command,
  }) async {
    final node.WorkflowAgentTaskView started = await executeNodeCommand(
      _channel,
      command,
    );

    while (true) {
      final node.DraftStatus status = await _readDraftStatus(
        workspaceId,
        started,
      );
      if (status case node.DraftDone(:final node.WorkflowView workflow)) {
        return workflow;
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  Stream<WorkflowDraftProgress> _pollDraftProgress({
    required WorkflowDraft draft,
    required WorkspaceId workspaceId,
    required node.WorkflowAgentTaskView started,
    required DraftedWorkflowStore storeDrafted,
  }) async* {
    final Workflow draftShell = buildDraftShell(
      workflowId: started.workflowId,
    );
    final AgentKind drafterKind = mapAgentKindFromNode(started.drafter);

    while (_runningDrafts.containsKey(draft)) {
      final List<node.Run> runs = await executeNodeCommand(
        _channel,
        node.ListRunsCommand(taskId: started.taskId),
      );
      final node.DraftStatus status;
      try {
        status = await _readDraftStatus(workspaceId, started);
      } on Object {
        if (!_runningDrafts.containsKey(draft)) {
          return;
        }
        rethrow;
      }

      if (status case node.DraftDone(:final node.WorkflowView workflow)) {
        yield buildFinishedDraftProgress(
          drafted: storeDrafted(workflow),
          runs: runs,
          drafterKind: drafterKind,
        );
        return;
      }

      final WorkflowDraftProgress? progress = buildWorkingDraftProgress(
        runs: runs,
        draftShell: draftShell,
        drafterKind: drafterKind,
      );
      if (progress != null) {
        yield progress;
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  Future<node.DraftStatus> _readDraftStatus(
    WorkspaceId workspaceId,
    node.WorkflowAgentTaskView started,
  ) {
    return executeNodeCommand(
      _channel,
      node.WorkflowDraftStatusCommand(
        workspaceId: workspaceId,
        taskId: started.taskId,
        workflowId: started.workflowId,
      ),
    );
  }
}
