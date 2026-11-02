import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';

const RuleId _styleGuideRuleId = RuleId('rule-follow-app-style-guide');
const RuleId _disabledRuleId = RuleId('rule-ask-before-adding-dependency');
const RuleDetailRoute _styleGuideRoute = RuleDetailRoute(_styleGuideRuleId);
const String _deleteQuestion = 'Delete "Follow the app style guide"?';
const String _deleteExplanation =
    'Agents stop getting it in AGENTS.md from their next run.';

const List<String> _galleryDetailTexts = <String>[
  'Rules',
  'Follow the app style guide',
  'Delete',
  'Edit',
  'Details',
  'For any text a customer will read.',
  'Applies to',
  'acme',
  'acme-app',
  'Status',
  'On',
  'Added',
  '9 October 2026',
];

Future<AppNavigation> _openRuleDetail(
  WidgetTester tester,
  AppDependencies dependencies,
) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: desktopSize,
    route: const SectionRoute(AppSection.rules),
    dependencies: dependencies,
  );
  navigation.openRoute(_styleGuideRoute);
  await pumpFrames(tester);
  return navigation;
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('rule detail page matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: _styleGuideRoute,
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in _galleryDetailTexts) {
        expect(find.text(text), findsWidgets, reason: text);
      }
    });
  }

  testWidgets('a rule that is off says so', (WidgetTester tester) async {
    await pumpApp(
      tester,
      size: desktopSize,
      route: const RuleDetailRoute(_disabledRuleId),
      dependencies: buildGalleryDependencies(),
    );

    expect(find.text('Off'), findsOne);
    expect(find.text('On'), findsNothing);
  });

  testWidgets('test_rules_screen_property_a_row_opens_its_rule', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9721);
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.rules),
      dependencies: dependencies,
    );

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Rule rule = pickOne(
        random,
        dependencies.ruleRepository.listRules(),
      );
      await tapVisible(tester, find.text(rule.title));
      await pumpFrames(tester);

      expect(navigation.currentRoute, RuleDetailRoute(rule.id));
      expect(find.text('Details'), findsOne);
      navigation.closeRoute();
      await pumpFrames(tester);
    }
  });

  testWidgets('test_rule_form_property_an_edit_keeps_the_rule', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9722);
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await _openRuleDetail(
      tester,
      dependencies,
    );

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String details = 'Details ${random.nextInt(100000)}';
      await tapVisible(tester, find.text('Edit'));
      await pumpFrames(tester);
      expect(navigation.currentRoute, const EditRuleRoute(_styleGuideRuleId));
      expect(find.text('Edit rule'), findsOne);

      await enterFieldText(tester, label: 'Details', text: details);
      await tapVisible(tester, find.text('Save rule'));
      await pumpFrames(tester);

      final Rule saved = dependencies.ruleRepository.findRule(
        _styleGuideRuleId,
      );
      expect(saved.details, details);
      expect(saved.title, 'Follow the app style guide');
      expect(saved.enabled, isTrue);
      expect(dependencies.ruleRepository.listRules().length, 4);
      expect(navigation.currentRoute, _styleGuideRoute);
      expect(find.text(details), findsOne);
    }
  });

  testWidgets('the edit form starts from the rule', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      size: desktopSize,
      route: const EditRuleRoute(_styleGuideRuleId),
      dependencies: buildGalleryDependencies(),
    );

    expect(findFieldText('Rule', 'Follow the app style guide'), findsOne);
    expect(
      findFieldText('Details', 'For any text a customer will read.'),
      findsOne,
    );
    expect(findFieldText('Workspaces', 'acme'), findsOne);
    expect(findFieldText('Projects', 'acme-app'), findsOne);
    expect(find.text('Add rule'), findsNothing);
  });

  testWidgets('deleting asks first and keeps the rule on Keep', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await _openRuleDetail(
      tester,
      dependencies,
    );

    await tapVisible(tester, find.text('Delete'));
    await pumpFrames(tester);
    expect(find.text(_deleteQuestion), findsOne);
    expect(find.text(_deleteExplanation), findsOne);
    expect(find.text("This can't be undone."), findsOne);
    await tapVisible(tester, find.text('Keep rule'));
    await pumpFrames(tester);

    expect(find.text(_deleteQuestion), findsNothing);
    expect(navigation.currentRoute, _styleGuideRoute);
    expect(dependencies.ruleRepository.listRules().length, 4);
  });

  testWidgets('a confirmed delete removes the rule and goes back', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await _openRuleDetail(
      tester,
      dependencies,
    );

    await tapVisible(tester, find.text('Delete'));
    await pumpFrames(tester);
    await tapVisible(tester, find.text('Delete rule'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.rules));
    expect(dependencies.ruleRepository.listRules().length, 3);
    expect(find.text('Follow the app style guide'), findsNothing);
  });

  testWidgets('a delete from a page opened over a runner page leaves first', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const RunnerDetailRoute(GalleryDeviceIds.gpuBox),
      dependencies: dependencies,
    );
    navigation.replaceRoute(_styleGuideRoute);
    await pumpFrames(tester);

    await tapVisible(tester, find.text('Delete'));
    await pumpFrames(tester);
    await tapVisible(tester, find.text('Delete rule'));
    await pumpFrames(tester);

    expect(tester.takeException(), isNull);
    expect(navigation.currentRoute, const SectionRoute(AppSection.rules));
    expect(dependencies.ruleRepository.listRules().length, 3);
  });
}
