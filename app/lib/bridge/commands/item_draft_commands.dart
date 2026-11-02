import 'package:agent_orchestration/bridge/codecs/drafting_task_views.dart';
import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

List<Object?> _encodeChosenFolders(List<DraftedRepository> chosenFolders) {
  return <Object?>[
    for (final DraftedRepository folder in chosenFolders) folder.toJson(),
  ];
}

final class DraftChange implements JsonEncodable {
  const DraftChange({required this.draft, required this.note});

  final ItemDraft draft;
  final String note;

  @override
  JsonObject toJson() {
    return <String, Object?>{'draft': draft.toJson(), 'note': note};
  }
}

final class DraftItemCommand implements NodeCommand<DraftingTaskView> {
  const DraftItemCommand({
    required this.workspaceId,
    required this.kind,
    required this.wish,
    required this.startedFrom,
    required this.change,
    required this.chosenFolders,
  });

  final WorkspaceId workspaceId;
  final DraftKind kind;
  final String wish;
  final String? startedFrom;
  final DraftChange? change;
  final List<DraftedRepository> chosenFolders;

  @override
  String get name => 'draft_item';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'kind': kind.wireName,
      'request': wish,
      'started_from': startedFrom,
      'change': change?.toJson(),
      'chosen_folders': _encodeChosenFolders(chosenFolders),
    };
  }

  @override
  DraftingTaskView decodeReply(Object? okValue) {
    return DraftingTaskView.fromJson(okValue);
  }
}

final class ItemDraftStatusCommand implements NodeCommand<ItemDraftStatus> {
  const ItemDraftStatusCommand({
    required this.workspaceId,
    required this.taskId,
    required this.kind,
    required this.chosenFolders,
  });

  final WorkspaceId workspaceId;
  final TaskId taskId;
  final DraftKind kind;
  final List<DraftedRepository> chosenFolders;

  @override
  String get name => 'item_draft_status';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'task_id': taskId.value,
      'kind': kind.wireName,
      'chosen_folders': _encodeChosenFolders(chosenFolders),
    };
  }

  @override
  ItemDraftStatus decodeReply(Object? okValue) {
    return ItemDraftStatus.fromJson(okValue);
  }
}
