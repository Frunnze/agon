import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/storage.dart';

import '../support/random_inputs.dart';

void main() {
  test('test_save_chosen_workspace_id_property_round_trips', () async {
    final Random random = seededRandom(10053);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const SharedPreferencesWorkspaceChoiceStore store =
        SharedPreferencesWorkspaceChoiceStore();
    expect(await store.readChosenWorkspaceId(), isNull);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceId workspaceId = WorkspaceId(randomText(random));
      await store.saveChosenWorkspaceId(workspaceId);
      expect(await store.readChosenWorkspaceId(), workspaceId);
    }
  });
}
