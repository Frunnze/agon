import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';

import 'fake_task_work_links.dart';

FakeWorkflowRepository buildGalleryWorkflowRepository() {
  return FakeWorkflowRepository(
    workflows: galleryWorkflows,
    changes: galleryWorkflowChanges,
    clock: FixedClock(galleryNow),
    currentDeviceId: GalleryDeviceIds.airLaptop,
    draftTemplate: galleryWorkflows[2],
    drafterDeviceId: GalleryDeviceIds.officeServer,
    draftStepDelay: Duration.zero,
    workspaceRepository: buildAcmeWorkspaceRepository(),
  );
}
