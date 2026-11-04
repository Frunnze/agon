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

const String _chooseFolderLabel = 'Choose folder…';
const String _createFolderLabel = 'Create a new folder';
const String _createProjectLabel = 'Create project';
const String _removeLabel = 'Remove';
const String _newFolderNote =
    'New folder · made with git when you create the project';
const String _noRepositoryProblem = 'Add at least one repo';
const List<String> _projectNames = <String>['billing', 'site-2', 'app'];
const List<String> _parentFolderNames = <String>['', '/work', '/code/web'];

final class _NewProjectPage {
  const _NewProjectPage({required this.dependencies, required this.picker});

  final AppDependencies dependencies;
  final FixedFolderPicker picker;

  List<Project> listCreatedProjects() {
    return dependencies.projectRepository.listProjects(
      GalleryWorkspaceIds.acme,
    );
  }
}

Future<_NewProjectPage> _pumpNewProject(WidgetTester tester) async {
  final FixedFolderPicker picker = FixedFolderPicker(null);
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    projectRepository: FakeProjectRepository(projects: const <Project>[]),
    folderPicker: picker,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: desktopSize,
    route: const NewProjectRoute(),
    dependencies: dependencies,
  );
  return _NewProjectPage(dependencies: dependencies, picker: picker);
}

String _pickParentFolder(Random random) {
  final String parentFolderName = pickOne(random, _parentFolderNames);
  return '${Directory.systemTemp.path}$parentFolderName';
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tapVisible(tester, find.text(text));
  await pumpFrames(tester);
}

String? _readOnlyRepositoryPath(Project project) {
  final String address = project.repositories.single.address;
  return parseLocalFolderAddress(address)?.path;
}

void main() {
  testWidgets('test_choose_folder_property_the_picked_folder_becomes_a_repo', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9411);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String parent = _pickParentFolder(random);
      final String name = pickOne(random, _projectNames);
      final _NewProjectPage page = await _pumpNewProject(tester);
      page.picker.chosenPath = '$parent/$name';

      await _tapText(tester, _chooseFolderLabel);
      await _tapText(tester, _createProjectLabel);

      expect(page.picker.chooseCount, 1);
      final Project created = page.listCreatedProjects().single;
      expect(_readOnlyRepositoryPath(created), '$parent/$name');
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a cancelled folder pick adds no repo', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final _NewProjectPage page = await _pumpNewProject(tester);
    await enterFieldText(tester, label: 'Name', text: 'billing');

    await _tapText(tester, _chooseFolderLabel);
    await _tapText(tester, _createProjectLabel);

    expect(page.picker.chooseCount, 1);
    expect(find.text(_noRepositoryProblem), findsOneWidget);
    expect(page.listCreatedProjects(), isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_create_new_folder_property_project_gets_the_new_folder', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9412);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String parent = _pickParentFolder(random);
      final String name = pickOne(random, _projectNames);
      final _NewProjectPage page = await _pumpNewProject(tester);
      page.picker.chosenPath = parent;

      await _tapText(tester, _createFolderLabel);
      await enterFieldText(tester, label: 'Name', text: name);
      await pumpFrames(tester);

      expect(find.text('$parent/$name'), findsOneWidget);
      expect(find.text(_newFolderNote), findsOneWidget);
      expect(page.listCreatedProjects(), isEmpty);
      await _tapText(tester, _createProjectLabel);

      final Project created = page.listCreatedProjects().single;
      expect(created.name, name);
      expect(_readOnlyRepositoryPath(created), '$parent/$name');
      expect(page.picker.chooseCount, 1);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('an existing folder is refused with its reason', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final String parent = Directory.systemTemp.path;
    final _NewProjectPage page = await _pumpNewProject(tester);
    await page.dependencies.deviceRepository.createLocalFolder(
      parent: parent,
      name: 'billing',
    );
    page.picker.chosenPath = parent;

    await enterFieldText(tester, label: 'Name', text: 'billing');
    await _tapText(tester, _createFolderLabel);
    await _tapText(tester, _createProjectLabel);

    expect(
      find.text(
        'the folder $parent/billing already exists, so choose another '
        'name or place',
      ),
      findsOneWidget,
    );
    expect(page.listCreatedProjects(), isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a cancelled place or a removed new folder adds nothing', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final _NewProjectPage page = await _pumpNewProject(tester);
    await enterFieldText(tester, label: 'Name', text: 'billing');

    await _tapText(tester, _createFolderLabel);
    expect(find.text(_newFolderNote), findsNothing);
    final String parent = Directory.systemTemp.path;
    page.picker.chosenPath = parent;
    await _tapText(tester, _createFolderLabel);
    expect(find.text('$parent/billing'), findsOneWidget);
    await _tapText(tester, _removeLabel);
    await _tapText(tester, _createProjectLabel);

    expect(find.text(_newFolderNote), findsNothing);
    expect(find.text(_noRepositoryProblem), findsOneWidget);
    expect(page.listCreatedProjects(), isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('phones offer no new folder', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _pumpNewProject(tester);

    expect(find.text(_createFolderLabel), findsNothing);
    expect(find.text(_chooseFolderLabel), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
