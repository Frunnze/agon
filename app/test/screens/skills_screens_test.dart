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

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';

const String _skillsFootnote =
    'Agents use automatic skills on their own when the work fits. Other '
    'skills run only when a task, job or workflow agent picks them.';

const List<String> _gallerySkillTexts = <String>[
  'Skills are instructions an agent can follow for one kind of work.',
  'ios-release',
  'Build, sign and upload the iOS app',
  'acme · acme-app',
  'release, feature-pipeline',
  'code-review',
  'feature-pipeline, 1 job',
  'git-cleanup',
  'acme · all projects',
  '1 task',
  'write-tests',
  'Built in',
  'Not used yet',
  _skillsFootnote,
];

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('skills page matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.skills),
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in _gallerySkillTexts) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text('Automatic'), findsNWidgets(2));
      expect(find.text('When chosen'), findsNWidgets(2));
      expect(
        find.text('Used by'),
        size == desktopSize ? findsOne : findsNothing,
      );
    });
  }

  testWidgets('a new skill is saved and listed', (WidgetTester tester) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.skills),
      dependencies: dependencies,
    );

    await tester.tap(find.text('New skill'));
    await pumpFrames(tester);
    expect(navigation.currentRoute, const NewSkillRoute());
    navigation.replaceRoute(NewItemFormRoute(DraftKind.skill));
    await pumpFrames(tester);

    await enterFieldText(tester, label: 'Name', text: 'release-notes');
    await enterFieldText(
      tester,
      label: 'What it does',
      text: 'Write release notes from merged pull requests',
    );
    await enterFieldText(
      tester,
      label: 'Instructions',
      text: 'List pull requests merged since the last tag.',
    );
    await addFieldTag(tester, label: 'Workspaces', tag: 'acme');
    await addFieldTag(tester, label: 'Projects', tag: 'docs');
    await tapVisible(tester, find.text('Only when chosen'));
    await pumpFrames(tester);
    await tapVisible(tester, find.text('Save skill'));
    await pumpFrames(tester);

    final Skill saved = dependencies.skillRepository.listSkills().last;
    expect(saved.name, 'release-notes');
    expect(saved.usage, SkillUsage.whenChosen);
    expect((saved.scope.projects as OnlyProjects).projects, <Object>[
      GalleryProjectIds.docs,
    ]);
    expect(navigation.currentRoute, const SectionRoute(AppSection.skills));
    expect(find.text('release-notes'), findsOneWidget);
    expect(find.text('acme · docs'), findsOneWidget);
  });

  testWidgets('test_skill_form_property_bad_names_are_never_saved', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9701);
    final AppDependencies dependencies = buildGalleryDependencies();
    await pumpApp(
      tester,
      size: desktopSize,
      route: NewItemFormRoute(DraftKind.skill),
      dependencies: dependencies,
    );
    final List<String> badNames = <String>[
      'Release Notes',
      'code-review',
      '',
      'a' * 41,
    ];

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await enterFieldText(
        tester,
        label: 'Name',
        text: pickOne(random, badNames),
      );
      await enterFieldText(tester, label: 'What it does', text: 'Summary');
      await enterFieldText(tester, label: 'Instructions', text: 'Do it.');
      await tapVisible(tester, find.text('Save skill'));
      await pumpFrames(tester);

      expect(dependencies.skillRepository.listSkills().length, 4);
    }
  });

  testWidgets('a taken skill name is explained', (WidgetTester tester) async {
    await pumpApp(
      tester,
      size: desktopSize,
      route: NewItemFormRoute(DraftKind.skill),
      dependencies: buildGalleryDependencies(),
    );

    await enterFieldText(tester, label: 'Name', text: 'code-review');
    await tapVisible(tester, find.text('Save skill'));
    await pumpFrames(tester);

    expect(find.text('A skill named code-review already exists'), findsOne);
    expect(find.text('Say what the skill does'), findsOne);
    expect(find.text('Write the instructions'), findsOne);
  });

  testWidgets('cancel leaves both forms without saving', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.skills),
      dependencies: dependencies,
    );

    navigation.openRoute(NewItemFormRoute(DraftKind.skill));
    await pumpFrames(tester);
    await tapVisible(tester, find.text('Cancel'));
    await pumpFrames(tester);
    navigation.openSection(const SectionRoute(AppSection.rules));
    navigation.openRoute(NewItemFormRoute(DraftKind.rule));
    await pumpFrames(tester);
    await tapVisible(tester, find.text('Cancel'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.rules));
    expect(dependencies.skillRepository.listSkills().length, 4);
    expect(dependencies.ruleRepository.listRules().length, 4);
  });
}
