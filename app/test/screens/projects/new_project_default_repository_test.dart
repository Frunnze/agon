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
import '../../support/fake_task_work_links.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';

const String _createProjectLabel = 'Create project';
const String _noRepositoryProblem = 'Add at least one repo';
const List<String> _projectNames = <String>['billing', 'site-2', 'app-9'];
const List<TargetPlatform> _computerPlatforms = <TargetPlatform>[
  TargetPlatform.macOS,
  TargetPlatform.linux,
  TargetPlatform.windows,
];
const List<TargetPlatform> _phonePlatforms = <TargetPlatform>[
  TargetPlatform.android,
  TargetPlatform.iOS,
];

typedef _NewProjectPage = ({
  AppDependencies dependencies,
  FixedFolderPicker picker,
});

Future<_NewProjectPage> _pumpNewProject(WidgetTester tester) async {
  final FixedFolderPicker picker = FixedFolderPicker(null);
  final AppDependencies galleryBase = buildGalleryDependencies();
  final AppDependencies dependencies = replaceRepositories(
    galleryBase,
    projectRepository: buildProjectRepositoryOver(
      galleryBase,
      const <Project>[],
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
  return (dependencies: dependencies, picker: picker);
}

List<Project> _listCreatedProjects(_NewProjectPage page) {
  return page.dependencies.projectRepository.listProjects(
    GalleryWorkspaceIds.acme,
  );
}

Future<void> _createWithName(WidgetTester tester, String name) async {
  await enterFieldText(tester, label: 'Name', text: name);
  await tapVisible(tester, find.text(_createProjectLabel));
  await pumpFrames(tester);
}

void main() {
  testWidgets(
    'test_prepare_new_projects_folder_property_name_only_names_first_repo',
    (WidgetTester tester) async {
      final Random random = seededRandom(9937);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        debugDefaultTargetPlatformOverride = pickOne(
          random,
          _computerPlatforms,
        );
        final String name = pickOne(random, _projectNames);
        final _NewProjectPage page = await _pumpNewProject(tester);

        await _createWithName(tester, name);

        expect(find.text(_noRepositoryProblem), findsNothing);
        final Project created = _listCreatedProjects(page).single;
        expect(created.name, name);
        final String? repositoryPath = parseLocalFolderAddress(
          created.repositories.single.address,
        )?.path;
        expect(repositoryPath, '$fixedNewProjectsFolder/$name');
        expect(page.picker.prepareCount, 1);
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'test_prepare_new_projects_folder_property_added_repo_needs_no_default',
    (WidgetTester tester) async {
      final Random random = seededRandom(9938);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        debugDefaultTargetPlatformOverride = pickOne(
          random,
          _computerPlatforms,
        );
        final String name = pickOne(random, _projectNames);
        final String repositoryName = pickOne(random, _projectNames);
        final String address = 'github.com/acme/$repositoryName';
        final _NewProjectPage page = await _pumpNewProject(tester);
        await enterFieldText(tester, label: 'Repos', text: address);
        await tapVisible(tester, find.text('Add repo'));
        await pumpFrames(tester);

        await _createWithName(tester, name);

        final Project created = _listCreatedProjects(page).single;
        expect(created.repositories.single.address, address);
        expect(page.picker.prepareCount, 0);
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'test_prepare_new_projects_folder_property_phones_still_ask_for_a_repo',
    (WidgetTester tester) async {
      final Random random = seededRandom(9939);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        debugDefaultTargetPlatformOverride = pickOne(random, _phonePlatforms);
        final String name = pickOne(random, _projectNames);
        final _NewProjectPage page = await _pumpNewProject(tester);

        await _createWithName(tester, name);

        expect(find.text(_noRepositoryProblem), findsOneWidget);
        expect(_listCreatedProjects(page), isEmpty);
        expect(page.picker.prepareCount, 0);
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'test_prepare_new_projects_folder_property_blank_name_makes_no_folder',
    (WidgetTester tester) async {
      final Random random = seededRandom(9940);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        debugDefaultTargetPlatformOverride = pickOne(
          random,
          _computerPlatforms,
        );
        final _NewProjectPage page = await _pumpNewProject(tester);

        await _createWithName(tester, ' ' * random.nextInt(3));

        expect(find.text('Give it a name'), findsOneWidget);
        expect(_listCreatedProjects(page), isEmpty);
        expect(page.picker.prepareCount, 0);
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
