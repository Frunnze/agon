import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/sample_folder_paths.dart';
import '../support/workflow_repositories.dart';

const List<String> _folderNames = <String>['billing-ui', 'app', 'site'];
const ProjectId _folderProjectId = ProjectId('folder-project');

Project _folderProject({required DeviceId deviceId, required String name}) {
  return Project(
    id: _folderProjectId,
    workspaceId: GalleryWorkspaceIds.acme,
    name: 'billing',
    repositories: <Repository>[
      const Repository(
        address: 'github.com/acme/billing',
        defaultBranch: 'main',
        agentAccess: AgentAccess.readOnly,
      ),
      Repository(
        address: renderLocalFolderAddress(
          deviceId: deviceId,
          path: buildTemporaryFolderPath(name),
        ),
        defaultBranch: 'main',
        agentAccess: AgentAccess.pushAfterApproval,
      ),
    ],
    approvalPolicy: null,
  );
}

bool _hasRunner(DeviceId deviceId) {
  return galleryRunners.any((Runner runner) => runner.deviceId == deviceId);
}

void main() {
  test(
    'test_build_task_form_options_property_names_folders_without_runner',
    () {
      final Random random = seededRandom(9501);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Device device = pickOne(random, galleryDevices);
        final String name = pickOne(random, _folderNames);
        final Project project = _folderProject(
          deviceId: device.id,
          name: name,
        );

        final TaskFormOptions options = buildTaskFormOptions(
          projects: <Project>[project, ...galleryProjects],
          workflows: galleryWorkflows,
          findPendingChange:
              buildGalleryWorkflowRepository().findPendingChange,
          runners: galleryRunners,
          deviceNames: DeviceNames(galleryDevices),
          skills: gallerySkills,
          chosenTarget: const AnyFreeRunner(),
        );

        final MissingFolderRunner? missing =
            options.missingFolderRunners[_folderProjectId];
        expect(missing == null, _hasRunner(device.id));
        expect(
          missing?.deviceName,
          _hasRunner(device.id) ? null : device.name,
        );
        expect(missing?.folderName, _hasRunner(device.id) ? null : name);
        for (final Project galleryProject in galleryProjects) {
          expect(options.missingFolderRunners[galleryProject.id], isNull);
        }
      }
    },
  );

  testWidgets('test_task_form_property_says_when_the_folder_has_no_runner', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = pickOne(random, _folderNames);
      final DeviceId deviceId = random.nextBool()
          ? GalleryDeviceIds.airLaptop
          : GalleryDeviceIds.macStudio;
      final AppDependencies dependencies = replaceRepositories(
        buildGalleryDependencies(),
        projectRepository: FakeProjectRepository(
          projects: <Project>[
            _folderProject(deviceId: deviceId, name: name),
            ...galleryProjects,
          ],
        ),
      );
      await pumpApp(
        tester,
        size: desktopSize,
        route: NewItemFormRoute(DraftKind.task),
        dependencies: dependencies,
      );

      final bool hasRunner = _hasRunner(deviceId);
      final Matcher shown = hasRunner ? findsNothing : findsOneWidget;
      expect(find.byType(FolderRunnerNotice), shown);
      expect(find.text('air-laptop has no runner'), shown);
      expect(
        find.text(
          '$name is a folder on air-laptop, so only air-laptop can work on '
          'billing. The task waits until it runs tasks.',
        ),
        shown,
      );
    }
  });
}
