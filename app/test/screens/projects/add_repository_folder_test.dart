import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';

const String _addRepositoryLabel = 'Add repo';
const String _chooseFolderLabel = 'Choose folder…';
const String _alreadyAddedProblem = 'This repo is already added';
const List<String> _folderNames = <String>['billing', 'site-2', 'app'];
const List<String> _parentFolderNames = <String>['', '/work', '/code/web'];

final class _ProjectPage {
  const _ProjectPage({required this.dependencies, required this.picker});

  final AppDependencies dependencies;
  final FixedFolderPicker picker;

  List<String> listRepositoryFolderPaths() {
    final Project project = dependencies.projectRepository.findProject(
      GalleryProjectIds.acmeApp,
    );
    final List<String> folderPaths = <String>[];
    for (final Repository repository in project.repositories) {
      final LocalFolderAddress? folder = parseLocalFolderAddress(
        repository.address,
      );
      if (folder != null) {
        folderPaths.add(folder.path);
      }
    }
    return folderPaths;
  }
}

Future<_ProjectPage> _pumpProjectPage(WidgetTester tester) async {
  final FixedFolderPicker picker = FixedFolderPicker(null);
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    folderPicker: picker,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: desktopSize,
    route: const ProjectRoute(GalleryProjectIds.acmeApp),
    dependencies: dependencies,
  );
  return _ProjectPage(dependencies: dependencies, picker: picker);
}

String _pickFolderPath(Random random) {
  final String parentFolderName = pickOne(random, _parentFolderNames);
  final String folderName = pickOne(random, _folderNames);
  return '${Directory.systemTemp.path}$parentFolderName/$folderName';
}

Future<void> _tapText(WidgetTester tester, Finder target) async {
  await tapVisible(tester, target);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_add_repository_property_the_picked_folder_joins_project', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9511);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String folderPath = _pickFolderPath(random);
      final _ProjectPage page = await _pumpProjectPage(tester);
      page.picker.chosenPath = folderPath;

      await _tapText(tester, find.text(_addRepositoryLabel));
      await _tapText(tester, find.text(_chooseFolderLabel));

      expect(page.picker.chooseCount, 1);
      expect(page.listRepositoryFolderPaths(), contains(folderPath));
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_add_repository_property_a_typed_folder_joins_project', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9512);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String folderPath = _pickFolderPath(random);
      final _ProjectPage page = await _pumpProjectPage(tester);

      await _tapText(tester, find.text(_addRepositoryLabel));
      await enterFieldText(tester, label: 'Address', text: folderPath);
      await _tapText(tester, find.text(_addRepositoryLabel).last);

      expect(page.listRepositoryFolderPaths(), contains(folderPath));
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('phones offer no folder in the add repo dialog', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _pumpProjectPage(tester);

    await _tapText(tester, find.text(_addRepositoryLabel));

    expect(find.text(_chooseFolderLabel), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_add_repository_property_a_folder_is_added_only_once', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9513);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String folderPath = _pickFolderPath(random);
      final _ProjectPage page = await _pumpProjectPage(tester);
      page.picker.chosenPath = folderPath;
      await _tapText(tester, find.text(_addRepositoryLabel));
      await _tapText(tester, find.text(_chooseFolderLabel));
      final int repositoryCount = page.listRepositoryFolderPaths().length;

      await _tapText(tester, find.text(_addRepositoryLabel));
      await _tapText(tester, find.text(_chooseFolderLabel));

      expect(find.text(_alreadyAddedProblem), findsOneWidget);
      expect(page.listRepositoryFolderPaths(), hasLength(repositoryCount));
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_add_repository_property_a_refused_folder_shows_why', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9514);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String folderName = pickOne(random, _folderNames);
      final String homePath = '~/$folderName';
      final _ProjectPage page = await _pumpProjectPage(tester);
      final List<String> pathsBefore = page.listRepositoryFolderPaths();

      await _tapText(tester, find.text(_addRepositoryLabel));
      await enterFieldText(tester, label: 'Address', text: homePath);
      await _tapText(tester, find.text(_addRepositoryLabel).last);

      expect(
        find.text('the folder "$homePath" is not an absolute path'),
        findsOneWidget,
      );
      expect(page.listRepositoryFolderPaths(), pathsBefore);
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
