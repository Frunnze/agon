import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_library_action_repositories.dart';

const WorkflowId _builtWorkflowId = GalleryWorkflowIds.release;
const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);
const String _removeAgentLabel = 'Remove agent';

final class _BuilderPage {
  late WorkflowRepository workflowRepository;
  late AppNavigation navigation;
  late int agentsWhenOpened;

  Future<void> open(
    WidgetTester tester, {
    required Size size,
    required PlannedRefusal refusal,
  }) async {
    final AppDependencies gallery = buildGalleryDependencies();
    workflowRepository = RefusingWorkflowRepository(
      stored: gallery.workflowRepository,
      refusal: refusal,
    );
    navigation = await pumpApp(
      tester,
      size: size,
      route: _workflowsRoute,
      dependencies: replaceRepositories(
        gallery,
        workflowRepository: workflowRepository,
      ),
    );
    navigation.openRoute(
      const WorkflowBuilderRoute(
        _builtWorkflowId,
        opening: BuilderOpening.forEditing,
      ),
    );
    await pumpFrames(tester);
    agentsWhenOpened = countAgents();
  }

  Future<void> openWithAddedAgent(
    WidgetTester tester, {
    required Size size,
    required PlannedRefusal refusal,
  }) async {
    await open(tester, size: size, refusal: refusal);
    await tapButtonLabelled(tester, addAgentLabel);
  }

  int countAgents() {
    return workflowRepository.findWorkflow(_builtWorkflowId).agents.length;
  }

  void expectBackOnWorkflows() {
    expect(navigation.routes, const <AppRoute>[_workflowsRoute]);
  }
}

RefusedActionCase _buildBuilderCase({
  required String functionName,
  required String tapLabel,
  required String actionLabel,
  required OpenRefusingPage Function(_BuilderPage page) chooseOpening,
  required void Function(_BuilderPage page) expectSucceeded,
}) {
  final _BuilderPage page = _BuilderPage();

  return RefusedActionCase(
    functionName: functionName,
    actionLabel: actionLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: chooseOpening(page),
    performAction: (tester) => tapButtonLabelled(tester, tapLabel),
    expectSucceeded: (tester) => expectSucceeded(page),
  );
}

List<RefusedActionCase> _buildBuilderCases() {
  return <RefusedActionCase>[
    _buildBuilderCase(
      functionName: 'add_step',
      tapLabel: addAgentLabel,
      actionLabel: changeSettingLabel,
      chooseOpening: (page) => page.open,
      expectSucceeded: (page) {
        expect(page.countAgents(), page.agentsWhenOpened + 1);
      },
    ),
    _buildBuilderCase(
      functionName: 'remove_agent',
      tapLabel: _removeAgentLabel,
      actionLabel: changeSettingLabel,
      chooseOpening: (page) => page.openWithAddedAgent,
      expectSucceeded: (page) {
        expect(page.countAgents(), page.agentsWhenOpened);
      },
    ),
    _buildBuilderCase(
      functionName: 'fill_agent_settings',
      tapLabel: fillInWithAgentLabel,
      actionLabel: fillInWithAgentLabel,
      chooseOpening: (page) => page.openWithAddedAgent,
      expectSucceeded: (page) {
        final String filledTask = page.workflowRepository
            .findWorkflow(_builtWorkflowId)
            .agents
            .last
            .task;
        expect(filledTask.trim(), isNotEmpty);
      },
    ),
    _buildBuilderCase(
      functionName: 'cancel_building',
      tapLabel: cancelBuildingLabel,
      actionLabel: cancelBuildingLabel,
      chooseOpening: (page) => page.openWithAddedAgent,
      expectSucceeded: (page) {
        page.expectBackOnWorkflows();
        expect(page.countAgents(), page.agentsWhenOpened);
      },
    ),
    _buildBuilderCase(
      functionName: 'sign_built_workflow',
      tapLabel: signAndSaveLabel,
      actionLabel: signAndSaveLabel,
      chooseOpening: (page) => page.open,
      expectSucceeded: (page) => page.expectBackOnWorkflows(),
    ),
  ];
}

void main() {
  int seed = 92601;
  for (final RefusedActionCase actionCase in _buildBuilderCases()) {
    registerRefusedActionProperties(actionCase, seed: seed);
    seed += 10;
  }
}
