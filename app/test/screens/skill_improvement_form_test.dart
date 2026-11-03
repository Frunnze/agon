import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';

const String _settingLabel = 'Agents may improve it';

const Map<SkillImprovement, String> _choiceTitles = <SkillImprovement, String>{
  SkillImprovement.never: 'Never',
  SkillImprovement.askMe: 'Ask me',
  SkillImprovement.auto: 'Auto',
};

const List<String> _choiceTexts = <String>[
  _settingLabel,
  'Never',
  'Agents never change this skill.',
  'Ask me',
  'An agent that used it may propose a better version for you to approve.',
  'Auto',
  "An agent's better version is saved at once. You can undo it.",
];

Future<void> _openForm(
  WidgetTester tester, {
  required AppDependencies dependencies,
  required AppRoute route,
}) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: desktopSize,
    route: const SectionRoute(AppSection.skills),
    dependencies: dependencies,
  );
  navigation.openRoute(route);
  await pumpFrames(tester);
}

Future<void> _fillNewSkill(WidgetTester tester, String name) async {
  await enterFieldText(tester, label: 'Name', text: name);
  await enterFieldText(tester, label: 'What it does', text: 'Summary');
  await enterFieldText(tester, label: 'Instructions', text: 'Do it.');
}

void main() {
  testWidgets('the form shows the setting after the usage choice', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      size: desktopSize,
      route: NewItemFormRoute(DraftKind.skill),
      dependencies: buildGalleryDependencies(),
    );

    for (final String text in _choiceTexts) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    final double usageTop = tester
        .getTopLeft(find.text('When agents use it'))
        .dy;
    final double settingTop = tester.getTopLeft(find.text(_settingLabel)).dy;
    expect(settingTop, greaterThan(usageTop));
  });

  testWidgets('a new skill saved untouched may never be improved', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await _openForm(
      tester,
      dependencies: dependencies,
      route: NewItemFormRoute(DraftKind.skill),
    );

    await _fillNewSkill(tester, 'untouched');
    await tapVisible(tester, find.text('Save skill'));
    await pumpFrames(tester);

    final Skill saved = dependencies.skillRepository.listSkills().last;
    expect(saved.name, 'untouched');
    expect(saved.improvement, SkillImprovement.never);
  });

  for (final SkillImprovement improvement in SkillImprovement.values) {
    testWidgets('choosing ${improvement.name} saves it on a new skill', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      await _openForm(
        tester,
        dependencies: dependencies,
        route: NewItemFormRoute(DraftKind.skill),
      );

      await _fillNewSkill(tester, 'chosen-${improvement.name.toLowerCase()}');
      await tapVisible(tester, find.text(_choiceTitles[improvement]!));
      await pumpFrames(tester);
      await tapVisible(tester, find.text('Save skill'));
      await pumpFrames(tester);

      final Skill saved = dependencies.skillRepository.listSkills().last;
      expect(saved.improvement, improvement);
    });

    testWidgets('choosing ${improvement.name} saves it on an edit', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      await _openForm(
        tester,
        dependencies: dependencies,
        route: const EditSkillRoute(GallerySkillIds.iosRelease),
      );

      await tapVisible(tester, find.text(_choiceTitles[improvement]!));
      await pumpFrames(tester);
      await tapVisible(tester, find.text('Save skill'));
      await pumpFrames(tester);

      final Skill saved = dependencies.skillRepository.findSkill(
        GallerySkillIds.iosRelease,
      );
      expect(saved.improvement, improvement);
      expect(saved.name, 'ios-release');
    });
  }

  testWidgets('an edit keeps the setting it was saved with', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await _openForm(
      tester,
      dependencies: dependencies,
      route: const EditSkillRoute(GallerySkillIds.iosRelease),
    );

    await tapVisible(tester, find.text('Save skill'));
    await pumpFrames(tester);

    final Skill saved = dependencies.skillRepository.findSkill(
      GallerySkillIds.iosRelease,
    );
    expect(saved.improvement, SkillImprovement.askMe);
  });
}
