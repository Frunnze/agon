import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/screens/workflows/workflow_quick_start.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_library_action_repositories.dart';
import '../support/refusing_work_repositories.dart';

const WorkflowId _changedWorkflowId = GalleryWorkflowIds.trainRanker;
const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);

final class _WorkflowPage {
  late WorkflowRepository workflowRepository;
  late AppNavigation navigation;

  Future<void> openChange(
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
    navigation.openRoute(const WorkflowChangeRoute(_changedWorkflowId));
    await pumpFrames(tester);
  }

  Future<void> openDetail(
    WidgetTester tester, {
    required Size size,
    required PlannedRefusal refusal,
  }) async {
    final AppDependencies gallery = buildGalleryDependencies();
    navigation = await pumpApp(
      tester,
      size: size,
      route: _workflowsRoute,
      dependencies: replaceRepositories(
        gallery,
        taskRepository: RefusingTaskRepository(
          stored: gallery.taskRepository,
          refusal: refusal,
        ),
      ),
    );
    navigation.openRoute(
      const WorkflowDetailRoute(GalleryWorkflowIds.release),
    );
    await pumpFrames(tester);
  }

  void expectChangeSettled() {
    expect(workflowRepository.findPendingChange(_changedWorkflowId), isNull);
    expect(navigation.routes, const <AppRoute>[_workflowsRoute]);
  }
}

RefusedActionCase _buildChangeCase({
  required String functionName,
  required String actionLabel,
}) {
  final _WorkflowPage page = _WorkflowPage();

  return RefusedActionCase(
    functionName: functionName,
    actionLabel: actionLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: page.openChange,
    performAction: (tester) => tapButtonLabelled(tester, actionLabel),
    expectSucceeded: (tester) => page.expectChangeSettled(),
  );
}

RefusedActionCase _buildStartNowCase() {
  final _WorkflowPage page = _WorkflowPage();

  return RefusedActionCase(
    functionName: 'start_now',
    actionLabel: startNowLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: page.openDetail,
    performAction: (tester) => tapButtonLabelled(tester, startNowLabel),
    expectSucceeded: (tester) {
      expect(page.navigation.routes.last, isA<TaskRunRoute>());
    },
  );
}

void main() {
  registerRefusedActionProperties(
    _buildChangeCase(
      functionName: 'discard_change',
      actionLabel: 'Discard change',
    ),
    seed: 91801,
  );
  registerRefusedActionProperties(
    _buildChangeCase(functionName: 'sign_change', actionLabel: 'Sign change'),
    seed: 91811,
  );
  registerRefusedActionProperties(_buildStartNowCase(), seed: 91821);
}
