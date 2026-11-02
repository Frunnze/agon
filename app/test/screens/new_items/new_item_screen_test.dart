import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';

const String _drafterLine = 'Claude Code is drafting on office-server';
const String _projectProblem =
    'No project in acme fits this. Ask for changes and name the project, '
    'or add the project first.';

void main() {
  for (final MapEntry<DraftKind, AppRoute> entry in newItemRoutes.entries) {
    final NewItemTexts texts = describeNewItem(entry.key);

    testWidgets('new ${texts.kindName} opens one chat input', (
      WidgetTester tester,
    ) async {
      await openNewItem(
        tester,
        route: entry.value,
        dependencies: buildNewItemDependencies(ScriptedItemDraftRepository()),
      );

      expect(find.text(texts.pageTitle), findsOneWidget);
      expect(find.text(texts.question), findsOneWidget);
      expect(find.text(newItemHint), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(isAppButtonOn(tester, texts.draftLabel), isTrue);
    });
  }

  testWidgets('an empty wish is refused before any drafting', (
    WidgetTester tester,
  ) async {
    final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
    await openNewItem(
      tester,
      route: const NewTaskRoute(),
      dependencies: buildNewItemDependencies(drafts),
    );

    await tester.tap(find.text('Draft task'));
    await pumpFrames(tester);

    expect(find.text(emptyWishProblem), findsOneWidget);
    expect(drafts.requests, isEmpty);
  });

  testWidgets('drafting shows the words and drafter, then the review', (
    WidgetTester tester,
  ) async {
    final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
    await openNewItem(
      tester,
      route: const NewTaskRoute(),
      dependencies: buildNewItemDependencies(drafts),
    );

    await startNewItemDraft(tester, 'Draft task');
    expect(drafts.latestRequest.wish, newItemWish);
    expect(drafts.latestRequest.kind, DraftKind.task);
    expect(drafts.latestRequest.change, isNull);
    expect(find.text(draftingSummary), findsOneWidget);
    expect(find.text(askedSectionTitle), findsOneWidget);
    expect(find.text(newItemWish), findsOneWidget);
    expect(find.text(startingDraftText), findsOneWidget);

    drafts.reportProgress(
      DraftRunning(
        drafterKind: AgentKind.claudeCode,
        drafterDeviceId: buildGalleryDependencies().deviceRepository
            .listDevices()
            .firstWhere((device) => device.name == 'office-server')
            .id,
      ),
    );
    await pumpFrames(tester);
    expect(find.text(_drafterLine), findsOneWidget);

    await finishNewItemDraft(
      tester,
      drafts,
      findGalleryItemDraft(DraftKind.task),
    );
    expect(find.text(filledSectionTitle), findsOneWidget);
    expect(find.text('Clean up old feature branches'), findsOneWidget);
    expect(find.text('acme-app'), findsOneWidget);
    expect(find.text('git-cleanup'), findsOneWidget);
    expect(isAppButtonOn(tester, approveLabel), isTrue);
  });

  testWidgets('problems are listed and keep approve off', (
    WidgetTester tester,
  ) async {
    final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
    await openNewItem(
      tester,
      route: const NewTaskRoute(),
      dependencies: buildNewItemDependencies(drafts),
    );
    await startNewItemDraft(tester, 'Draft task');

    final ItemDraft gallery = findGalleryItemDraft(DraftKind.task);
    await finishNewItemDraft(
      tester,
      drafts,
      ItemDraft(item: gallery.item, problems: <String>[_projectProblem]),
    );

    expect(find.text(draftProblemsTitle), findsOneWidget);
    expect(find.text(_projectProblem), findsOneWidget);
    expect(find.text(draftProblemsNote), findsOneWidget);
    expect(isAppButtonOn(tester, approveLabel), isFalse);
  });

  testWidgets('asking for changes drafts again with the note and draft', (
    WidgetTester tester,
  ) async {
    final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
    await openNewItem(
      tester,
      route: const NewJobRoute(),
      dependencies: buildNewItemDependencies(drafts),
    );
    await startNewItemDraft(tester, 'Draft job');
    final ItemDraft first = findGalleryItemDraft(DraftKind.job);
    await finishNewItemDraft(tester, drafts, first);

    await tester.enterText(find.byType(TextField).last, 'On Fridays');
    await tester.tap(find.text(sendChangeLabel));
    await pumpFrames(tester);

    final ItemDraftRequest changed = drafts.latestRequest;
    expect(drafts.requests, hasLength(2));
    expect(changed.wish, newItemWish);
    expect(changed.change!.note, 'On Fridays');
    expect(identical(changed.change!.draft, first.item), isTrue);
    expect(find.text(draftingSummary), findsOneWidget);

    drafts.failLatestDraft(StateError('the agent broke'));
    await pumpFrames(tester);
    expect(find.text('the agent broke'), findsOneWidget);
    await tester.tap(find.text(backToDraftLabel));
    await pumpFrames(tester);
    expect(find.text(filledSectionTitle), findsOneWidget);
    expect(find.text('Update dependencies'), findsOneWidget);
  });

  testWidgets('stop drafting returns to the words', (
    WidgetTester tester,
  ) async {
    final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
    await openNewItem(
      tester,
      route: const NewSkillRoute(),
      dependencies: buildNewItemDependencies(drafts),
    );
    await startNewItemDraft(tester, 'Draft skill');

    await tester.tap(find.text(stopDraftingLabel));
    await pumpFrames(tester);

    expect(drafts.stoppedRequests, <ItemDraftRequest>[drafts.latestRequest]);
    expect(find.text('What should agents know or do?'), findsOneWidget);
    expect(find.text(newItemWish), findsOneWidget);
  });

  testWidgets('leaving while drafting stops the draft', (
    WidgetTester tester,
  ) async {
    final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
    final AppNavigation navigation = await openNewItem(
      tester,
      route: const NewRuleRoute(presetProjectId: null),
      dependencies: buildNewItemDependencies(drafts),
    );
    await startNewItemDraft(tester, 'Draft rule');

    await tester.tap(find.text('Rules').last);
    await pumpFrames(tester);

    expect(drafts.stoppedRequests, hasLength(1));
    expect(navigation.currentRoute, isNot(isA<NewRuleRoute>()));
  });
}
