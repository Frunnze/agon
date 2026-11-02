import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';

const List<String> _galleryRuleTexts = <String>[
  "Each run's AGENTS.md gets the rules for its project.",
  'Never push to main',
  'Open a pull request instead.',
  'Follow the app style guide',
  'For any text a customer will read.',
  'Ask before adding a dependency',
  'AGENTS.md for acme-app',
  '- Never push to main.',
  '  Open a pull request instead.',
  "A project's own AGENTS.md is kept. These rules are added on top.",
];

Finder findRuleSwitch(String title) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is SwitchToggle && widget.semanticLabel == 'Use "$title"',
  );
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('rules page matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.rules),
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in _galleryRuleTexts) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text('Everywhere'), findsNWidgets(2));
      expect(find.text('acme-app'), findsOneWidget);
    });
  }

  testWidgets('test_rules_screen_property_switch_matches_the_rule', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9702);
    final AppDependencies dependencies = buildGalleryDependencies();
    await pumpApp(
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
      await tapVisible(tester, findRuleSwitch(rule.title));
      await pumpFrames(tester);

      for (final Rule current in dependencies.ruleRepository.listRules()) {
        final SwitchToggle toggle = tester.widget(
          findRuleSwitch(current.title),
        );
        expect(toggle.value, current.enabled);
      }
    }
  });

  testWidgets('turning a rule on adds it to the AGENTS.md preview', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.rules),
      dependencies: buildGalleryDependencies(),
    );
    expect(find.text('- Ask before adding a dependency.'), findsNothing);

    await tapVisible(tester, findRuleSwitch('Ask before adding a dependency'));
    await pumpFrames(tester);

    expect(find.text('- Ask before adding a dependency.'), findsOneWidget);
  });

  testWidgets('a new rule is added from the rules page', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: const SectionRoute(AppSection.rules),
      dependencies: dependencies,
    );

    await tester.tap(find.text('New rule'));
    await pumpFrames(tester);
    expect(navigation.currentRoute, const NewRuleRoute(presetProjectId: null));
    navigation.replaceRoute(NewItemFormRoute(DraftKind.rule));
    await pumpFrames(tester);

    await tapVisible(tester, find.text('Add rule'));
    await pumpFrames(tester);
    expect(find.text('Write the rule'), findsOneWidget);

    await enterFieldText(tester, label: 'Rule', text: 'Keep commits small');
    await enterFieldText(
      tester,
      label: 'Details',
      text: 'One change per commit, with a short message.',
    );
    await tapVisible(tester, find.text('Add rule'));
    await pumpFrames(tester);

    final Rule added = dependencies.ruleRepository.listRules().last;
    expect(added.title, 'Keep commits small');
    expect(added.scope.workspaces, isA<AllWorkspaces>());
    expect(navigation.currentRoute, const SectionRoute(AppSection.rules));
    expect(find.text('Keep commits small'), findsOneWidget);
  });

  testWidgets('a rule started from a project is scoped to it', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.projects),
      dependencies: dependencies,
    );
    navigation.openRoute(
      NewItemFormRoute(
        DraftKind.rule,
        presetProjectId: GalleryProjectIds.docs,
      ),
    );
    await pumpFrames(tester);

    expect(findFieldText('Workspaces', 'acme'), findsOneWidget);
    expect(findFieldText('Projects', 'docs'), findsOneWidget);
    await enterFieldText(tester, label: 'Rule', text: 'Keep docs short');
    await tapVisible(tester, find.text('Add rule'));
    await pumpFrames(tester);

    final Rule added = dependencies.ruleRepository.listRules().last;
    expect((added.scope.projects as OnlyProjects).projects, <Object>[
      GalleryProjectIds.docs,
    ]);
    expect((added.scope.workspaces as OnlyWorkspaces).workspaces, <Object>[
      GalleryWorkspaceIds.acme,
    ]);
    expect(navigation.currentRoute, const SectionRoute(AppSection.projects));
  });
}
