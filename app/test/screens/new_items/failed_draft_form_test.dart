import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/workflows/workflow_drafting_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';

void main() {
  testWidgets('test_failed_draft_property_offers_the_form_of_its_kind', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(8101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, DraftKind.values);
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final AppNavigation navigation = await openNewItem(
        tester,
        route: newItemRoutes[kind]!,
        dependencies: buildNewItemDependencies(drafts),
      );
      await startNewItemDraft(tester, 'Draft ${kind.name}');

      drafts.failLatestDraft(StateError('Not logged in'));
      await pumpFrames(tester);

      expect(find.text(draftFailedTitle), findsOneWidget, reason: '$kind');
      await tester.tap(find.text(fillInFormLabel));
      await pumpFrames(tester);

      final AppRoute current = navigation.currentRoute;
      expect(current, isA<NewItemFormRoute>(), reason: '$kind');
      expect((current as NewItemFormRoute).kind, kind);
    }
  });
}
