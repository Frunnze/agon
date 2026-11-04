import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/protected_files_repositories.dart';
import '../support/random_inputs.dart';
import '../support/server_group_repositories.dart';
import '../support/widget_harness.dart';

const String _addLabel = 'Add pattern';
const String _removeLabel = 'Remove';
const String _resetLabel = 'Reset to defaults';
const String _membersTitle = 'Devices in acme';
const List<String> _patternStems = <String>[
  '~/.config/secrets-',
  '*.pem.',
  '.env.',
  'keys/**/',
  '~/.aws/profile-',
];
const List<String> _blankTexts = <String>['', ' ', '   ', '\t', ' \n '];
const int _largestPatternCount = 5;

List<String> _randomPatterns(Random random, {required int least}) {
  final int patternCount = least + random.nextInt(_largestPatternCount);
  return <String>[
    for (int i = 0; i < patternCount; i += 1)
      '${pickOne(random, _patternStems)}$i',
  ];
}

String _randomPadding(Random random) => pickOne(random, _blankTexts);

Finder _findInSection(Finder matching) {
  return find.descendant(
    of: find.byType(ProtectedFilesSection),
    matching: matching,
  );
}

Future<FakeWorkspaceRepository> _openSettings(
  WidgetTester tester, {
  required List<String> patterns,
}) async {
  final FakeWorkspaceRepository repository = buildServerGroupRepository(
    galleryAppServerGroup,
  );
  await repository.saveProtectedFiles(
    workspaceId: GalleryWorkspaceIds.acme,
    patterns: patterns,
  );
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    workspaceRepository: repository,
  );

  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: desktopSize,
    route: const SectionRoute(AppSection.settings),
    dependencies: dependencies,
  );
  return repository;
}

List<String> _readSavedPatterns(FakeWorkspaceRepository repository) {
  return repository.currentWorkspace().protectedFiles;
}

Future<void> _addPattern(WidgetTester tester, String typedText) async {
  final Finder field = _findInSection(find.byType(TextField));
  await tester.ensureVisible(field);
  await tester.enterText(field, typedText);
  await tapVisible(tester, _findInSection(find.text(_addLabel)));
  await pumpFrames(tester);
}

Future<void> _removePattern(WidgetTester tester, int index) async {
  await tapVisible(tester, _findInSection(find.text(_removeLabel)).at(index));
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_protected_files_section_property_lists_every_pattern', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9941);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = _randomPatterns(random, least: 0);
      await _openSettings(tester, patterns: patterns);

      for (final String pattern in patterns) {
        final Finder shown = _findInSection(find.text(pattern));
        expect(shown, findsOneWidget, reason: pattern);

        final Text text = tester.widget<Text>(shown);
        expect(text.style?.fontFamily, AppFontFamilies.monospace);
      }
      expect(
        _findInSection(find.text(_removeLabel)),
        findsNWidgets(patterns.length),
      );
    }
  });

  testWidgets('the section follows the devices of the workspace', (
    WidgetTester tester,
  ) async {
    await _openSettings(tester, patterns: galleryDefaultProtectedFiles);

    final Rect members = tester.getRect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is PageSection && widget.title == _membersTitle,
      ),
    );
    final Rect section = tester.getRect(find.byType(ProtectedFilesSection));
    expect(section.top, greaterThan(members.bottom));
    expect(find.text("Files agents can't read"), findsOneWidget);
    expect(find.textContaining('Claude Code refuses them'), findsOneWidget);
  });

  testWidgets('test_add_pattern_property_saves_the_pattern_last', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9942);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = _randomPatterns(random, least: 0);
      final String added = 'added/$i/*.key';
      final FakeWorkspaceRepository repository = await _openSettings(
        tester,
        patterns: patterns,
      );

      final String typed =
          '${_randomPadding(random)}$added${_randomPadding(random)}';
      await _addPattern(tester, typed);

      expect(_readSavedPatterns(repository), <String>[...patterns, added]);
      expect(_findInSection(find.text(added)), findsOneWidget);
      expect(
        tester
            .widget<TextField>(_findInSection(find.byType(TextField)))
            .controller
            ?.text,
        isEmpty,
      );
    }
  });

  testWidgets('test_add_pattern_property_ignores_blank_and_listed_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9943);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = _randomPatterns(random, least: 1);
      final FakeWorkspaceRepository repository = await _openSettings(
        tester,
        patterns: patterns,
      );
      int saveCount = 0;
      repository.addListener(() => saveCount += 1);

      final String listed = pickOne(random, patterns);
      final String typed = random.nextBool()
          ? _randomPadding(random)
          : '${_randomPadding(random)}$listed${_randomPadding(random)}';
      await _addPattern(tester, typed);

      expect(saveCount, 0, reason: 'typed "$typed"');
      expect(_readSavedPatterns(repository), patterns);
    }
  });

  testWidgets('test_remove_pattern_property_saves_the_list_without_it', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9944);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = _randomPatterns(random, least: 1);
      final int removedIndex = random.nextInt(patterns.length);
      final String removed = patterns[removedIndex];
      final FakeWorkspaceRepository repository = await _openSettings(
        tester,
        patterns: patterns,
      );

      await _removePattern(tester, removedIndex);

      final List<String> expected = <String>[
        for (final String pattern in patterns)
          if (pattern != removed) pattern,
      ];
      expect(_readSavedPatterns(repository), expected);
      expect(_findInSection(find.text(removed)), findsNothing);
    }
  });

  testWidgets('test_reset_protected_files_property_restores_the_defaults', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9945);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = _randomPatterns(random, least: 0);
      final FakeWorkspaceRepository repository = await _openSettings(
        tester,
        patterns: patterns,
      );

      await tapVisible(tester, _findInSection(find.text(_resetLabel)));
      await pumpFrames(tester);

      expect(_readSavedPatterns(repository), galleryDefaultProtectedFiles);
      for (final String pattern in galleryDefaultProtectedFiles) {
        expect(_findInSection(find.text(pattern)), findsOneWidget);
      }
    }
  });

  testWidgets('test_remove_then_add_property_keeps_every_other_pattern', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9946);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = _randomPatterns(random, least: 1);
      final int removedIndex = random.nextInt(patterns.length);
      final String removed = patterns[removedIndex];
      final FakeWorkspaceRepository repository = await _openSettings(
        tester,
        patterns: patterns,
      );

      await _removePattern(tester, removedIndex);
      await _addPattern(tester, removed);

      final List<String> others = <String>[
        for (final String pattern in patterns)
          if (pattern != removed) pattern,
      ];
      expect(_readSavedPatterns(repository), <String>[...others, removed]);
    }
  });

  testWidgets('test_protected_files_section_property_shows_the_refusal', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9947);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String refusal =
          'the pattern [$i is not valid: ${randomWordPhrase(random)}';
      final RefusingProtectedFilesRepository repository =
          RefusingProtectedFilesRepository(
            inner: buildServerGroupRepository(galleryAppServerGroup),
            refusal: refusal,
          );
      await pumpScrollableAtWidth(
        tester,
        width: desktopWidth,
        child: ProtectedFilesSection(workspaceRepository: repository),
      );

      final String typed = '[$i';
      await _addPattern(tester, typed);

      expect(find.text(refusal), findsOneWidget);
      expect(
        tester
            .widget<TextField>(_findInSection(find.byType(TextField)))
            .controller
            ?.text,
        typed,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
