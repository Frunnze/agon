import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';

const SkillDetailRoute _iosReleaseRoute = SkillDetailRoute(
  GallerySkillIds.iosRelease,
);
const String _deleteQuestion = 'Delete ios-release?';
const String _deleteExplanation =
    'Agents stop using it. Tasks, jobs and workflows that chose it keep '
    'running without it.';

const List<String> _galleryDetailTexts = <String>[
  'Skills',
  'ios-release',
  'Build, sign and upload the iOS app',
  'Delete',
  'Edit',
  'How agents use it',
  'When agents use it',
  'Automatic',
  'Applies to',
  'acme',
  'acme-app',
  'Used by',
  'release, feature-pipeline',
  'Instructions',
  'Build the release scheme.',
  'Sign it.',
  'Upload it.',
];

Future<AppNavigation> _openSkillDetail(
  WidgetTester tester,
  AppDependencies dependencies,
) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: desktopSize,
    route: const SectionRoute(AppSection.skills),
    dependencies: dependencies,
  );
  navigation.openRoute(_iosReleaseRoute);
  await pumpFrames(tester);
  return navigation;
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('skill detail page matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: _iosReleaseRoute,
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in _galleryDetailTexts) {
        expect(find.text(text), findsWidgets, reason: text);
      }
    });
  }

  testWidgets('test_skills_screen_property_a_row_opens_its_skill', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9711);
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.skills),
      dependencies: dependencies,
    );

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Skill skill = pickOne(
        random,
        dependencies.skillRepository.listSkills(),
      );
      await tapVisible(tester, find.text(skill.name));
      await pumpFrames(tester);

      expect(navigation.currentRoute, SkillDetailRoute(skill.id));
      expect(find.text(skill.instructions.split('\n').first), findsOne);
      navigation.closeRoute();
      await pumpFrames(tester);
    }
  });

  testWidgets('test_skill_form_property_an_edit_keeps_the_skill', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9712);
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await _openSkillDetail(
      tester,
      dependencies,
    );

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String summary = 'Summary ${random.nextInt(100000)}';
      await tapVisible(tester, find.text('Edit'));
      await pumpFrames(tester);
      expect(
        navigation.currentRoute,
        const EditSkillRoute(GallerySkillIds.iosRelease),
      );
      expect(find.text('Edit skill'), findsOne);
      expect(findFieldText('Name', 'ios-release'), findsOne);

      await enterFieldText(tester, label: 'What it does', text: summary);
      await tapVisible(tester, find.text('Save skill'));
      await pumpFrames(tester);

      final Skill saved = dependencies.skillRepository.findSkill(
        GallerySkillIds.iosRelease,
      );
      expect(saved.summary, summary);
      expect(saved.name, 'ios-release');
      expect(dependencies.skillRepository.listSkills().length, 4);
      expect(navigation.currentRoute, _iosReleaseRoute);
      expect(find.text(summary), findsOne);
    }
  });

  testWidgets('an edit may not take another skill name', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.skills),
      dependencies: dependencies,
    );
    navigation.openRoute(const EditSkillRoute(GallerySkillIds.iosRelease));
    await pumpFrames(tester);

    await enterFieldText(tester, label: 'Name', text: 'code-review');
    await tapVisible(tester, find.text('Save skill'));
    await pumpFrames(tester);

    expect(find.text('A skill named code-review already exists'), findsOne);
    expect(
      dependencies.skillRepository.findSkill(GallerySkillIds.iosRelease).name,
      'ios-release',
    );
  });

  testWidgets('deleting asks first and keeps the skill on Keep', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await _openSkillDetail(
      tester,
      dependencies,
    );

    await tapVisible(tester, find.text('Delete'));
    await pumpFrames(tester);
    expect(find.text(_deleteQuestion), findsOne);
    expect(find.text(_deleteExplanation), findsOne);
    expect(find.text("This can't be undone."), findsOne);
    await tapVisible(tester, find.text('Keep skill'));
    await pumpFrames(tester);

    expect(find.text(_deleteQuestion), findsNothing);
    expect(navigation.currentRoute, _iosReleaseRoute);
    expect(dependencies.skillRepository.listSkills().length, 4);
  });

  testWidgets('a confirmed delete removes the skill and goes back', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await _openSkillDetail(
      tester,
      dependencies,
    );

    await tapVisible(tester, find.text('Delete'));
    await pumpFrames(tester);
    await tapVisible(tester, find.text('Delete skill'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.skills));
    expect(dependencies.skillRepository.listSkills().length, 3);
    expect(find.text('ios-release'), findsNothing);
    expect(find.text('code-review'), findsOne);
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
    navigation.replaceRoute(_iosReleaseRoute);
    await pumpFrames(tester);

    await tapVisible(tester, find.text('Delete'));
    await pumpFrames(tester);
    await tapVisible(tester, find.text('Delete skill'));
    await pumpFrames(tester);

    expect(tester.takeException(), isNull);
    expect(navigation.currentRoute, const SectionRoute(AppSection.skills));
    expect(dependencies.skillRepository.listSkills().length, 3);
  });
}
