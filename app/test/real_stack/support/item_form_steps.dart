import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/new_items/new_item_screen.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import 'stack_waiting.dart';

Future<void> replaceChatWithForm(
  WidgetTester tester, {
  required DraftKind kind,
}) async {
  await waitUntilShown(tester, find.byType(NewItemScreen));
  final AgentOrchestrationApp app = tester.widget(
    find.byType(AgentOrchestrationApp),
  );
  app.navigation.replaceRoute(NewItemFormRoute(kind));
  await waitUntilGone(tester, find.byType(NewItemScreen));
}
