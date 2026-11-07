import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_place_repositories.dart';

const SectionRoute _projectsRoute = SectionRoute(AppSection.projects);
const String _otherWorkspaceName = 'personal';
const String _createWorkspaceLabel = 'Create workspace';
const String _newWorkspaceName = 'side-projects';

final class _SwitcherPage {
  late WorkspaceRepository workspaceRepository;
  late AppNavigation navigation;

  Future<void> open(
    WidgetTester tester, {
    required Size size,
    required PlannedRefusal refusal,
  }) async {
    final AppDependencies gallery = buildGalleryDependencies();
    workspaceRepository = RefusingWorkspaceRepository(
      stored: gallery.workspaceRepository,
      refusal: refusal,
    );
    navigation = await pumpApp(
      tester,
      size: size,
      route: _projectsRoute,
      dependencies: replaceRepositories(
        gallery,
        workspaceRepository: workspaceRepository,
      ),
    );
    navigation.openRoute(const WorkspaceSwitcherRoute());
    await pumpFrames(tester);
  }

  void expectSwitchedTo(String workspaceName) {
    expect(workspaceRepository.currentWorkspace().name, workspaceName);
    expect(navigation.routes, const <AppRoute>[_projectsRoute]);
  }
}

RefusedActionCase _buildOpenWorkspaceCase() {
  final _SwitcherPage page = _SwitcherPage();

  return RefusedActionCase(
    functionName: 'open_workspace',
    actionLabel: 'Open',
    place: RefusalPlace.dialogOverPage,
    openPage: page.open,
    performAction: (tester) async {
      final Finder row = find.text(_otherWorkspaceName).last;
      await tester.ensureVisible(row);
      await tester.tap(row);
      await pumpFrames(tester);
    },
    expectSucceeded: (tester) => page.expectSwitchedTo(_otherWorkspaceName),
  );
}

RefusedActionCase _buildCreateWorkspaceCase() {
  final _SwitcherPage page = _SwitcherPage();

  return RefusedActionCase(
    functionName: 'create_workspace',
    actionLabel: _createWorkspaceLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) async {
      await page.open(tester, size: size, refusal: refusal);
      await tapButtonLabelled(tester, _createWorkspaceLabel);
    },
    performAction: (tester) async {
      await tester.enterText(find.byType(TextField), _newWorkspaceName);
      await tester.pump();
      await tapButtonLabelled(tester, _createWorkspaceLabel);
    },
    expectSucceeded: (tester) => page.expectSwitchedTo(_newWorkspaceName),
  );
}

void main() {
  registerRefusedActionProperties(_buildOpenWorkspaceCase(), seed: 92401);
  registerRefusedActionProperties(_buildCreateWorkspaceCase(), seed: 92411);
}
