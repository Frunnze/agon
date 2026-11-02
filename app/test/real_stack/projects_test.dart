import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../support/form_finders.dart';
import 'support/item_form_steps.dart';
import 'support/real_stack.dart';
import 'support/stack_catalog.dart';
import 'support/stack_folders.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';

const String _projectsTitle = 'Projects';
const String _newProjectTitle = 'New project';
const String _projectName = 'site';
const String _typedAddress = 'https://github.com/example/site.git';
const String _siteAddress = 'github.com/example/site';
const String _sitePath = 'example/site';
const String _docsAddress = 'github.com/example/docs';
const String _docsPath = 'example/docs';
const String _addRepositoryLabel = 'Add repo';
const String _addRepositoryDialogTitle = 'Add repo to $_projectName';
const String _removeRowLabel = 'Remove';
const String _removeRepositoryLabel = 'Remove repo';
const String _folderName = 'billing-ui';

List<String> _readRepositoryAddresses(List<node.ProjectView> projects) {
  final List<String> addresses = <String>[];
  for (final node.Repository repository
      in projects.single.project.repositories) {
    addresses.add(repository.address);
  }
  return addresses;
}

Future<void> _openProjectPage(WidgetTester tester) async {
  await openRailSection(
    tester,
    label: _projectsTitle,
    pageTitle: _projectsTitle,
  );
  await tapAndWait(
    tester,
    find.text(_projectName),
    expected: findPageTitle(_projectName),
  );
  await waitUntilGone(tester, findPageTitle(_projectsTitle));
}

Future<void> _addDocsRepository(WidgetTester tester) async {
  await tapAndWait(
    tester,
    find.text(_addRepositoryLabel),
    expected: find.text(_addRepositoryDialogTitle),
  );
  await enterFieldText(tester, label: 'Address', text: _docsAddress);
  await tapWhenShown(tester, find.text(_addRepositoryLabel).last);
  await waitUntilGone(tester, find.text(_addRepositoryDialogTitle));
  await waitUntilShown(tester, find.text(_docsPath));
}

Future<void> _removeSiteRepository(WidgetTester tester) async {
  final Finder siteRemoveButton = find.text(_removeRowLabel).first;
  await waitUntilShown(tester, find.text(_sitePath));
  await tapAndWait(
    tester,
    siteRemoveButton,
    expected: find.text(_removeRepositoryLabel),
  );
  await tapWhenShown(tester, find.text(_removeRepositoryLabel));
  await waitUntilGone(tester, find.text(_removeRepositoryLabel));
  await waitUntilGone(tester, find.text(_sitePath));
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_create_project_property_typed_repository_reaches_the_node',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await openRailSection(
        tester,
        label: _projectsTitle,
        pageTitle: _projectsTitle,
      );
      await tapAndWait(
        tester,
        find.text(_newProjectTitle).first,
        expected: findPageTitle(_newProjectTitle),
      );
      await waitUntilGone(tester, findPageTitle(_projectsTitle));
      await replaceChatWithForm(tester, kind: DraftKind.project);

      await enterFieldText(tester, label: 'Name', text: _projectName);
      await enterFieldText(tester, label: 'Repos', text: _typedAddress);
      await tapWhenShown(tester, find.text(_addRepositoryLabel));
      await waitUntilShown(tester, find.text(_sitePath));
      await tapWhenShown(tester, find.text('Read only'));
      await tapWhenShown(tester, find.text('Create project'));
      await waitUntilShown(tester, findPageTitle(_projectName));
      await waitUntilGone(tester, findPageTitle(_newProjectTitle));
      expect(find.text('1 repo · 0 tasks'), findsOneWidget);

      await tapWhenShown(
        tester,
        find.widgetWithText(BackLinkButton, _projectsTitle),
      );
      await waitUntilShown(tester, findPageTitle(_projectsTitle));
      await waitUntilGone(tester, findPageTitle(_projectName));
      expect(find.text(_projectName), findsOneWidget);
      expect(find.text(_sitePath), findsOneWidget);
      expect(find.text('1 repo'), findsOneWidget);

      final List<node.ProjectView> projects = await listHomeProjects(
        tester,
        stack: stack,
      );
      final node.Project created = projects.single.project;
      expect(created.name, _projectName);
      expect(created.repositories.single.address, _siteAddress);
      expect(
        created.repositories.single.agentAccess,
        node.AgentAccess.readOnly,
      );
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_create_project_property_typed_folder_reaches_the_node',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final RealStack stack = await RealStack.openWithAccount(tester);
      final Directory folder = await askNode(
        tester,
        () => createGitFolder(stack.workingDirectory, _folderName),
      );
      await openRailSection(
        tester,
        label: _projectsTitle,
        pageTitle: _projectsTitle,
      );
      await tapAndWait(
        tester,
        find.text(_newProjectTitle).first,
        expected: findPageTitle(_newProjectTitle),
      );
      await replaceChatWithForm(tester, kind: DraftKind.project);

      await enterFieldText(tester, label: 'Name', text: _projectName);
      await enterFieldText(tester, label: 'Repos', text: folder.path);
      await tapWhenShown(tester, find.text(_addRepositoryLabel));
      await waitUntilShown(tester, find.text(_folderName));
      expect(find.text('on $appDeviceName · main'), findsOneWidget);
      await tapWhenShown(tester, find.text('Create project'));
      await waitUntilShown(tester, findPageTitle(_projectName));

      final List<node.ProjectView> projects = await listHomeProjects(
        tester,
        stack: stack,
      );
      expect(
        projects.single.project.repositories.single.address,
        'local:${stack.appDeviceId.value}:${folder.path}',
      );
      await stack.close(tester);
      debugDefaultTargetPlatformOverride = null;
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_change_repositories_property_dialogs_reach_the_node',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await createProjectOnNode(
        tester,
        stack: stack,
        projectName: _projectName,
        repositoryAddress: _siteAddress,
      );
      await _openProjectPage(tester);

      await _addDocsRepository(tester);
      expect(find.text('2 repos · 0 tasks'), findsOneWidget);
      final List<node.ProjectView> withDocs = await listHomeProjects(
        tester,
        stack: stack,
      );
      expect(
        _readRepositoryAddresses(withDocs),
        unorderedEquals(<String>[_siteAddress, _docsAddress]),
      );

      await _removeSiteRepository(tester);
      expect(find.text(_docsPath), findsOneWidget);
      expect(find.text('1 repo · 0 tasks'), findsOneWidget);
      final List<node.ProjectView> withoutSite = await listHomeProjects(
        tester,
        stack: stack,
      );
      expect(_readRepositoryAddresses(withoutSite), <String>[_docsAddress]);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
