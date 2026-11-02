import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_item_drafts.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/scripted_item_draft_repository.dart';

const String newItemWish = 'Clean up the merged feature branches';

final Map<DraftKind, AppRoute> newItemRoutes = <DraftKind, AppRoute>{
  DraftKind.task: const NewTaskRoute(),
  DraftKind.job: const NewJobRoute(),
  DraftKind.project: const NewProjectRoute(),
  DraftKind.skill: const NewSkillRoute(),
  DraftKind.rule: const NewRuleRoute(presetProjectId: null),
};

AppDependencies buildNewItemDependencies(ScriptedItemDraftRepository drafts) {
  return replaceRepositories(
    buildGalleryDependencies(),
    itemDraftRepository: drafts,
  );
}

Future<AppNavigation> openNewItem(
  WidgetTester tester, {
  required AppRoute route,
  required AppDependencies dependencies,
}) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: desktopSize,
    route: SectionRoute(route.section),
    dependencies: dependencies,
  );
  navigation.openRoute(route);
  await pumpFrames(tester);
  return navigation;
}

Finder findAppButton(String label) {
  return find.widgetWithText(AppButton, label);
}

bool isAppButtonOn(WidgetTester tester, String label) {
  final AppButton button = tester.widget(findAppButton(label).first);
  return button.onPressed != null;
}

Future<void> startNewItemDraft(WidgetTester tester, String draftLabel) async {
  await tester.enterText(find.byType(TextField).first, newItemWish);
  await tester.tap(find.text(draftLabel));
  await pumpFrames(tester);
}

Future<void> finishNewItemDraft(
  WidgetTester tester,
  ScriptedItemDraftRepository drafts,
  ItemDraft draft,
) async {
  drafts.reportProgress(DraftFinished(draft));
  await pumpFrames(tester);
}

ItemDraft findGalleryItemDraft(DraftKind kind) =>
    buildGalleryItemDrafts()[kind]!;
