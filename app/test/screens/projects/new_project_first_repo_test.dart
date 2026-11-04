import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';

const String _chooseFolderLabel = 'Choose folder…';
const String _addRepoLabel = 'Add repo';
const String _removeLabel = 'Remove';
const String _startedGitNote = 'Started git in this folder';
final String _folderParent = '${Directory.systemTemp.path}/work';
const String _gitlessFolderName = 'notes';
const String _laterAddress = 'github.com/acme/later';
const List<String> _folderNames = <String>['Billing UI', 'site_2', 'app'];
const List<String> _repositoryNames = <String>['Web_App', 'billing', 'API.v2'];
const List<String> _typedNames = <String>['mine', 'billing-2', 'x'];

Future<FixedFolderPicker> _pumpNewProject(WidgetTester tester) async {
  final FixedFolderPicker picker = FixedFolderPicker(null);
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    projectRepository: FakeProjectRepository(projects: const <Project>[]),
    deviceRepository: FakeDeviceRepository(
      devices: galleryDevices,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      peerAddressProblem: null,
      gitlessFolderPaths: <String>{'$_folderParent/$_gitlessFolderName'},
    ),
    folderPicker: picker,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: desktopSize,
    route: const NewProjectRoute(),
    dependencies: dependencies,
  );
  return picker;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tapVisible(tester, find.text(text));
  await pumpFrames(tester);
}

Future<void> _addAddress(WidgetTester tester, String address) async {
  await enterFieldText(tester, label: 'Repos', text: address);
  await _tapText(tester, _addRepoLabel);
}

Future<void> _chooseFolder(
  WidgetTester tester,
  FixedFolderPicker picker,
  String name,
) async {
  picker.chosenPath = '$_folderParent/$name';
  await _tapText(tester, _chooseFolderLabel);
}

Future<String> _addRandomRepository(
  WidgetTester tester,
  FixedFolderPicker picker,
  Random random,
) async {
  if (random.nextBool()) {
    final String folderName = pickOne(random, _folderNames);
    await _chooseFolder(tester, picker, folderName);
    return folderName;
  }
  final String repositoryName = pickOne(random, _repositoryNames);
  await _addAddress(tester, 'github.com/acme/$repositoryName');
  return repositoryName;
}

void _expectName(String name) {
  expect(findFieldText('Name', name), findsOneWidget);
}

void main() {
  testWidgets('test_new_project_property_first_repo_fills_an_empty_name', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FixedFolderPicker picker = await _pumpNewProject(tester);

      final String firstName = await _addRandomRepository(
        tester,
        picker,
        random,
      );
      _expectName(convertToProjectName(firstName));
      await _addAddress(tester, _laterAddress);

      _expectName(convertToProjectName(firstName));
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_new_project_property_a_typed_name_is_kept', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FixedFolderPicker picker = await _pumpNewProject(tester);
      final String typedName = pickOne(random, _typedNames);

      await enterFieldText(tester, label: 'Name', text: typedName);
      await _addRandomRepository(tester, picker, random);

      _expectName(typedName);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_new_project_property_a_filled_name_follows_a_new_first', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FixedFolderPicker picker = await _pumpNewProject(tester);

      await _addRandomRepository(tester, picker, random);
      await _tapText(tester, _removeLabel);
      final String nextName = await _addRandomRepository(
        tester,
        picker,
        random,
      );

      _expectName(convertToProjectName(nextName));
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_new_project_property_started_git_shows_under_its_repo', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FixedFolderPicker picker = await _pumpNewProject(tester);

      await _chooseFolder(tester, picker, pickOne(random, _folderNames));
      expect(find.textContaining(_startedGitNote), findsNothing);
      await _chooseFolder(tester, picker, _gitlessFolderName);

      expect(
        find.text('on air-laptop · main · $_startedGitNote'),
        findsOneWidget,
      );
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
