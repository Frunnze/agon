import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_place_repositories.dart';

const String _removeLabel = 'Remove';
const String _confirmRemovalLabel = 'Remove repo';

RefusedActionCase _buildRemoveRepositoryCase() {
  late ProjectRepository projectRepository;
  late int repositoriesBeforeRemoval;

  return RefusedActionCase(
    functionName: 'remove_repository',
    actionLabel: _confirmRemovalLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies gallery = buildGalleryDependencies();
      projectRepository = RefusingProjectRepository(
        stored: gallery.projectRepository,
        refusal: refusal,
      );
      await pumpApp(
        tester,
        size: size,
        route: const ProjectRoute(GalleryProjectIds.acmeApp),
        dependencies: replaceRepositories(
          gallery,
          projectRepository: projectRepository,
        ),
      );
      repositoriesBeforeRemoval = _countRepositories(projectRepository);
    },
    performAction: (tester) async {
      await tapButtonLabelled(tester, _removeLabel);
      await tapButtonLabelled(tester, _confirmRemovalLabel);
    },
    expectSucceeded: (tester) {
      final int repositories = _countRepositories(projectRepository);
      expect(repositories, repositoriesBeforeRemoval - 1);
      expect(find.text(_confirmRemovalLabel), findsNothing);
    },
  );
}

int _countRepositories(ProjectRepository projectRepository) {
  return projectRepository
      .findProject(GalleryProjectIds.acmeApp)
      .repositories
      .length;
}

void main() {
  registerRefusedActionProperties(_buildRemoveRepositoryCase(), seed: 92501);
}
