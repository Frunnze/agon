import 'package:agent_orchestration/bridge/codecs/drafting_task_views.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/deletion_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/item_draft_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/run_commands.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed/node_command_execution.dart';
import 'package:agent_orchestration/data/repository/item_draft_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

final class _RunningItemDraft {
  const _RunningItemDraft(this.start);

  final Future<node.DraftingTaskView> start;
}

final class NodeBackedItemDraftRepository implements ItemDraftRepository {
  NodeBackedItemDraftRepository({
    required NodeCommandChannel channel,
    required WorkspaceRepository workspaceRepository,
    required Duration pollInterval,
  }) : _channel = channel,
       _workspaceRepository = workspaceRepository,
       _pollInterval = pollInterval;

  final NodeCommandChannel _channel;
  final WorkspaceRepository _workspaceRepository;
  final Duration _pollInterval;
  final Map<ItemDraftRequest, _RunningItemDraft> _runningDrafts =
      <ItemDraftRequest, _RunningItemDraft>{};

  @override
  Stream<ItemDraftProgress> draftItem(ItemDraftRequest request) async* {
    if (request.wish.trim().isEmpty) {
      throw ArgumentError.value(request.wish, 'wish', 'Say what you want');
    }
    if (_runningDrafts.containsKey(request)) {
      throw StateError('This ${request.kind.name} is already being drafted');
    }

    final WorkspaceId workspaceId = _workspaceRepository.currentWorkspace().id;
    final _RunningItemDraft running = _RunningItemDraft(
      executeNodeCommand(_channel, _buildDraftCommand(workspaceId, request)),
    );
    _runningDrafts[request] = running;
    try {
      final node.DraftingTaskView started = await running.start;
      yield* _pollDraft(
        request: request,
        statusCommand: node.ItemDraftStatusCommand(
          workspaceId: workspaceId,
          taskId: started.taskId,
          kind: mapDraftKindToNode(request.kind),
        ),
        drafterKind: mapAgentKindFromNode(started.drafter),
      );
    } finally {
      _runningDrafts.remove(request);
    }
  }

  @override
  Future<void> stopDrafting(ItemDraftRequest request) async {
    final _RunningItemDraft? running = _runningDrafts[request];
    if (running == null) {
      throw StateError('No ${request.kind.name} is being drafted');
    }

    final node.DraftingTaskView started = await running.start;
    final List<node.Run> runs = await executeNodeCommand(
      _channel,
      node.ListRunsCommand(taskId: started.taskId),
    );
    final node.Run? draftingRun = findLatestRun(runs);
    if (draftingRun == null) {
      throw StateError('The ${request.kind.name} draft has no run to stop');
    }

    await executeNodeCommand(
      _channel,
      node.CancelRunCommand(runId: draftingRun.id),
    );
    _runningDrafts.remove(request);
    await executeNodeCommand(
      _channel,
      node.DeleteTaskCommand(taskId: started.taskId),
    );
  }

  node.DraftItemCommand _buildDraftCommand(
    WorkspaceId workspaceId,
    ItemDraftRequest request,
  ) {
    final ItemDraftChange? change = request.change;
    final node.DraftChange? wireChange = change == null
        ? null
        : node.DraftChange(
            draft: mapDraftedItemToNode(change.draft, request.kind),
            note: change.note,
          );

    return node.DraftItemCommand(
      workspaceId: workspaceId,
      kind: mapDraftKindToNode(request.kind),
      wish: request.wish,
      startedFrom: request.startedFrom,
      change: wireChange,
    );
  }

  Stream<ItemDraftProgress> _pollDraft({
    required ItemDraftRequest request,
    required node.ItemDraftStatusCommand statusCommand,
    required AgentKind drafterKind,
  }) async* {
    while (_runningDrafts.containsKey(request)) {
      final node.ItemDraftStatus status;
      try {
        status = await executeNodeCommand(_channel, statusCommand);
      } on Object {
        if (!_runningDrafts.containsKey(request)) {
          return;
        }
        rethrow;
      }

      if (status case node.ItemDraftDone()) {
        yield DraftFinished(mapItemDraftFromNode(status));
        return;
      }

      final List<node.Run> runs = await executeNodeCommand(
        _channel,
        node.ListRunsCommand(taskId: statusCommand.taskId),
      );
      final DeviceId? drafterDeviceId = findDrafterDeviceId(runs);
      if (drafterDeviceId != null) {
        yield DraftRunning(
          drafterKind: drafterKind,
          drafterDeviceId: drafterDeviceId,
        );
      }
      await Future<void>.delayed(_pollInterval);
    }
  }
}
