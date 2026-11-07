import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_work_repositories.dart';

const RunId _activeRunId = GalleryRunIds.release42;
const String _cancelRunLabel = 'Cancel run';
const String _activeRunLabel = 'release #42';

RefusedActionCase _buildCancelRunCase() {
  late TaskRepository taskRepository;

  return RefusedActionCase(
    functionName: 'cancel_run',
    actionLabel: _cancelRunLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies gallery = buildGalleryDependencies();
      taskRepository = RefusingTaskRepository(
        stored: gallery.taskRepository,
        refusal: refusal,
      );
      await pumpApp(
        tester,
        size: size,
        route: const TaskRunRoute(_activeRunId),
        dependencies: replaceRepositories(
          gallery,
          taskRepository: taskRepository,
        ),
      );
    },
    performAction: (tester) async {
      await tapButtonLabelled(tester, _cancelRunLabel);
      expect(find.text(_activeRunLabel), findsWidgets);
    },
    expectSucceeded: (tester) {
      expect(isRunActive(taskRepository.findRun(_activeRunId)), isFalse);
    },
  );
}

void main() {
  registerRefusedActionProperties(_buildCancelRunCase(), seed: 91101);
}
