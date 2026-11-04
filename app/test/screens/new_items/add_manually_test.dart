import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/jobs/job_form_screen.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/rules/rule_form_screen.dart';
import 'package:agent_orchestration/screens/skills/skill_form_screen.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/screens/tasks/task_form_screen.dart';
import 'package:agent_orchestration/screens/workflows/new_workflow_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import '../../support/widget_harness.dart';
import 'new_item_harness.dart';

final Map<DraftKind, Type> _manualFormScreens = <DraftKind, Type>{
  DraftKind.task: TaskFormScreen,
  DraftKind.job: JobFormScreen,
  DraftKind.skill: SkillFormScreen,
  DraftKind.rule: RuleFormScreen,
};

Map<AppRoute, String> _listNewPageDraftLabels() {
  final Map<AppRoute, String> draftLabels = <AppRoute, String>{
    const NewWorkflowRoute(): draftWorkflowLabel,
  };
  for (final MapEntry<DraftKind, AppRoute> entry in newItemRoutes.entries) {
    draftLabels[entry.value] = describeNewItem(entry.key).draftLabel;
  }
  return draftLabels;
}

Future<AppNavigation> _openNewPage(
  WidgetTester tester,
  AppRoute newItemRoute, {
  required Size size,
}) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: size,
    route: SectionRoute(newItemRoute.section),
    dependencies: buildNewItemDependencies(ScriptedItemDraftRepository()),
  );
  navigation.openRoute(newItemRoute);
  await pumpFrames(tester);
  return navigation;
}

Future<void> _tapAddManually(WidgetTester tester) async {
  await tester.tap(findAppButton(addManuallyLabel));
  await pumpFrames(tester);
}

bool _isBlankOrSchedulePreset(String fieldText) {
  return fieldText.isEmpty || fieldText == defaultScheduleTimeText;
}

bool _followsInSameRow(Rect leading, Rect following) {
  final bool sharesRow = following.center.dy == leading.center.dy;
  final double gap = following.left - leading.right;
  return sharesRow && gap == AppSpacing.space2;
}

bool _followsOnNextRow(Rect leading, Rect following) {
  final bool startsAtSameLeft = following.left == leading.left;
  final bool sharesCenter = following.center.dx == leading.center.dx;
  final double gap = following.top - leading.bottom;
  return (startsAtSameLeft || sharesCenter) && gap == AppSpacing.space2;
}

List<String> _readFieldTexts(WidgetTester tester) {
  final List<String> fieldTexts = <String>[];
  for (final EditableText field in tester.widgetList<EditableText>(
    find.byType(EditableText),
  )) {
    fieldTexts.add(field.controller.text);
  }
  return fieldTexts;
}

void main() {
  for (final DraftKind kind in _manualFormScreens.keys) {
    testWidgets('add manually opens the empty ${kind.name} form', (
      WidgetTester tester,
    ) async {
      final AppNavigation navigation = await _openNewPage(
        tester,
        newItemRoutes[kind]!,
        size: desktopSize,
      );
      await tester.enterText(find.byType(TextField).first, newItemWish);

      await _tapAddManually(tester);

      final AppRoute formRoute = navigation.currentRoute;
      expect(formRoute, isA<NewItemFormRoute>());
      expect((formRoute as NewItemFormRoute).kind, kind);
      expect(find.byType(_manualFormScreens[kind]!), findsOneWidget);
      final List<String> fieldTexts = _readFieldTexts(tester);
      expect(fieldTexts, isNotEmpty);
      expect(fieldTexts.every(_isBlankOrSchedulePreset), isTrue);
    });

    testWidgets('the ${kind.name} form goes back to the New page', (
      WidgetTester tester,
    ) async {
      final AppNavigation navigation = await _openNewPage(
        tester,
        newItemRoutes[kind]!,
        size: desktopSize,
      );
      await _tapAddManually(tester);

      await tester.tap(find.byType(BackLinkButton));
      await pumpFrames(tester);

      expect(navigation.currentRoute, newItemRoutes[kind]);
      expect(find.text(describeNewItem(kind).draftLabel), findsOneWidget);
    });
  }

  testWidgets('a rule added manually lands on Rules, not the New page', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _openNewPage(
      tester,
      newItemRoutes[DraftKind.rule]!,
      size: desktopSize,
    );
    await _tapAddManually(tester);

    await enterFieldText(tester, label: 'Rule', text: 'Keep commits small');
    await tester.tap(findAppButton('Add rule'));
    await pumpFrames(tester);

    expect(navigation.routes, const <AppRoute>[
      SectionRoute(AppSection.rules),
    ]);
    expect(find.text('Keep commits small'), findsOneWidget);
  });

  testWidgets('test_item_request_view_property_add_manually_beside_draft', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9131);
    final Map<AppRoute, String> newPageDraftLabels = _listNewPageDraftLabels();

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final MapEntry<AppRoute, String> newPage = pickOne(
        random,
        newPageDraftLabels.entries.toList(),
      );
      final double width = randomWidth(
        random,
        least: phoneWidth,
        most: widestWidth,
      );
      await _openNewPage(
        tester,
        newPage.key,
        size: Size(width, desktopHeight),
      );

      final Rect draftButton = tester.getRect(findAppButton(newPage.value));
      final Rect addManuallyButton = tester.getRect(
        findAppButton(addManuallyLabel),
      );
      final bool isBesideDraft =
          _followsInSameRow(draftButton, addManuallyButton) ||
          _followsOnNextRow(draftButton, addManuallyButton);
      expect(isBesideDraft, isTrue, reason: '${newPage.key} at $width');
    }
  });
}
