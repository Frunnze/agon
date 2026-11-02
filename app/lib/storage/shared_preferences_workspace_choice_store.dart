import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/workspace_choice_store.dart';

const String _chosenWorkspaceKey = 'chosen_workspace_id';

final class SharedPreferencesWorkspaceChoiceStore
    implements WorkspaceChoiceStore {
  const SharedPreferencesWorkspaceChoiceStore();

  @override
  Future<WorkspaceId?> readChosenWorkspaceId() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    final String? storedIdentifier = preferences.getString(
      _chosenWorkspaceKey,
    );
    if (storedIdentifier == null) {
      return null;
    }
    return WorkspaceId(storedIdentifier);
  }

  @override
  Future<void> saveChosenWorkspaceId(WorkspaceId workspaceId) async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    await preferences.setString(_chosenWorkspaceKey, workspaceId.value);
  }
}
