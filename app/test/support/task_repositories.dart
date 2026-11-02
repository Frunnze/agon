import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/task.dart';

import 'workflow_repositories.dart';

FakeTaskRepository buildGalleryTaskRepository() {
  return FakeTaskRepository(
    tasks: <Task>[...galleryTasks, ...galleryJobs],
    runs: galleryRuns,
    clock: FixedClock(galleryNow),
    currentDeviceId: GalleryDeviceIds.airLaptop,
    workflowRepository: buildGalleryWorkflowRepository(),
  );
}
