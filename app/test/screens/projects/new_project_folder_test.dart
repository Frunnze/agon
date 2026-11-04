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
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';

const List<String> _folderNames = <String>['billing-ui', 'app', 'site_2'];
const String _chooseFolderLabel = 'Choose folder…';
const String _computerHint =
    'Paste a GitHub address, choose a folder on this computer or create a '
    'new one. Add as many as needed.';
const String _phoneHint = 'Paste a GitHub address. Add as many as needed.';

Future<AppDependencies> _pumpNewProject(
  WidgetTester tester, {
  required String? chosenPath,
}) async {
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    projectRepository: FakeProjectRepository(projects: const <Project>[]),
    folderPicker: FixedFolderPicker(chosenPath),
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: desktopSize,
    route: const NewProjectRoute(),
    dependencies: dependencies,
  );
  return dependencies;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tapVisible(tester, find.text(text));
  await pumpFrames(tester);
}

void _expectFolderRow(String name) {
  expect(findFieldText('Repos', name), findsOneWidget);
  expect(find.text('on air-laptop · main'), findsOneWidget);
}

void main() {
  test('test_can_choose_folders_property_only_computers_choose', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final bool isComputer =
          platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux;

      expect(canChooseFolders(platform), isComputer);
    }
  });

  testWidgets('test_new_project_property_typed_folder_becomes_a_folder_row', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = pickOne(random, _folderNames);
      final String path = '${Directory.systemTemp.path}/$name';
      final AppDependencies dependencies = await _pumpNewProject(
        tester,
        chosenPath: null,
      );

      await enterFieldText(tester, label: 'Repos', text: '$path/');
      await _tapText(tester, 'Add repo');
      _expectFolderRow(name);
      await enterFieldText(tester, label: 'Name', text: 'billing');
      await _tapText(tester, 'Create project');

      final Project created = dependencies.projectRepository
          .listProjects(GalleryWorkspaceIds.acme)
          .single;
      final LocalFolderAddress? folder = parseLocalFolderAddress(
        created.repositories.single.address,
      );
      expect(folder?.deviceId, GalleryDeviceIds.airLaptop);
      expect(folder?.path, path);
      expect(created.repositories.single.defaultBranch, 'main');
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_new_project_property_chosen_folder_is_added_once', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final Random random = seededRandom(9402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = pickOne(random, _folderNames);
      await _pumpNewProject(
        tester,
        chosenPath: '${Directory.systemTemp.path}/$name',
      );

      expect(find.text(_computerHint), findsOneWidget);
      await _tapText(tester, _chooseFolderLabel);
      _expectFolderRow(name);
      await _tapText(tester, _chooseFolderLabel);
      _expectFolderRow(name);
      expect(find.text('This repo is already added'), findsOneWidget);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_new_project_property_problems_show_in_the_field', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final Random random = seededRandom(9403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = pickOne(random, _folderNames);
      await _pumpNewProject(tester, chosenPath: null);

      await enterFieldText(tester, label: 'Repos', text: '~/$name');
      await _tapText(tester, 'Add repo');
      expect(
        find.text('the folder "~/$name" is not an absolute path'),
        findsOneWidget,
      );
      await _tapText(tester, _chooseFolderLabel);
      expect(find.text('on air-laptop · main'), findsNothing);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('phones add GitHub addresses only', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _pumpNewProject(
      tester,
      chosenPath: '${Directory.systemTemp.path}/app',
    );

    expect(find.text(_chooseFolderLabel), findsNothing);
    expect(find.text(_phoneHint), findsOneWidget);
    await enterFieldText(
      tester,
      label: 'Repos',
      text: '${Directory.systemTemp.path}/app',
    );
    await _tapText(tester, 'Add repo');
    expect(
      find.text('Paste an address like github.com/acme/repo'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
