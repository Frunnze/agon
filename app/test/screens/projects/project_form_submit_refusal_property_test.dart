import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/fake_task_work_links.dart';
import '../../support/form_finders.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_place_repositories.dart';

const String _createProjectLabel = 'Create project';
const String _repositoryAddress = 'github.com/acme/approvals';

RefusedActionCase _buildCreateProjectCase() {
  late AppNavigation navigation;

  return RefusedActionCase(
    functionName: 'project_form_submit',
    actionLabel: _createProjectLabel,
    place: RefusalPlace.bannerOnPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies gallery = buildGalleryDependencies();
      navigation = await pumpApp(
        tester,
        size: size,
        route: const NewProjectRoute(),
        dependencies: replaceRepositories(
          gallery,
          projectRepository: RefusingProjectRepository(
            stored: buildProjectRepositoryOver(gallery, const <Project>[]),
            refusal: refusal,
          ),
        ),
      );
      await addFieldTag(tester, label: 'Repos', tag: _repositoryAddress);
      await pumpFrames(tester);
    },
    performAction: (tester) => tapButtonLabelled(tester, _createProjectLabel),
    expectSucceeded: (tester) {
      expect(navigation.routes.last, isA<ProjectRoute>());
    },
  );
}

void main() {
  registerRefusedActionProperties(_buildCreateProjectCase(), seed: 92101);
}
