import 'package:agent_orchestration/data/models/identifiers.dart';

abstract final class GalleryWorkspaceIds {
  static const WorkspaceId acme = WorkspaceId('workspace-acme');
  static const WorkspaceId personal = WorkspaceId('workspace-personal');
}

abstract final class GalleryDeviceIds {
  static const DeviceId airLaptop = DeviceId(
    '3b7f0c9e2a514d6b8e1f4a7c9d2e5b80',
  );
  static const DeviceId macStudio = DeviceId(
    '8c2d4e6f1a3b5c7d9e0f2a4b6c8d0e1f',
  );
  static const DeviceId officeServer = DeviceId(
    '5e1a7b3c9d2f4e6a8b0c1d3e5f7a9b2c',
  );
  static const DeviceId gpuBox = DeviceId('2a9fb3c6d1e84f5a7b2c9d0e3f6a1b4c');
  static const DeviceId pixelPhone = DeviceId(
    '6d4c2b0a9e8f7d6c5b4a3e2f1d0c9b8a',
  );
  static const DeviceId oldMacbook = DeviceId(
    '1f3e5d7c9b2a4f6e8d0c2b4a6f8e0d2c',
  );
  static const DeviceId mainMac = DeviceId('9c7a5e3b1d8f6a4c2e0b9d7f5a3c1e8b');
}

abstract final class GalleryProjectIds {
  static const ProjectId acmeApp = ProjectId('project-acme-app');
  static const ProjectId mlRanker = ProjectId('project-ml-ranker');
  static const ProjectId docs = ProjectId('project-docs');
  static const ProjectId blog = ProjectId('project-blog');
}

abstract final class GalleryWorkflowIds {
  static const WorkflowId release = WorkflowId('workflow-release');
  static const WorkflowId nightlyTests = WorkflowId('workflow-nightly-tests');
  static const WorkflowId featurePipeline = WorkflowId(
    'workflow-feature-pipeline',
  );
  static const WorkflowId trainRanker = WorkflowId('workflow-train-ranker');
  static const WorkflowId docsSync = WorkflowId('workflow-docs-sync');
}

abstract final class GallerySkillIds {
  static const SkillId iosRelease = SkillId('skill-ios-release');
  static const SkillId codeReview = SkillId('skill-code-review');
  static const SkillId gitCleanup = SkillId('skill-git-cleanup');
  static const SkillId writeTests = SkillId('skill-write-tests');
}

abstract final class GalleryTaskIds {
  static const TaskId shipRelease24 = TaskId('task-ship-release-2-4');
  static const TaskId cleanUpBranches = TaskId('task-clean-up-branches');
  static const TaskId shipRelease23 = TaskId('task-ship-release-2-3');
  static const TaskId writeApiDocs = TaskId('task-write-api-docs');
  static const TaskId renameBillingModule = TaskId(
    'task-rename-billing-module',
  );
  static const TaskId nightlyTests = TaskId('job-nightly-tests');
  static const TaskId updateDependencies = TaskId('job-update-dependencies');
  static const TaskId retrainRanker = TaskId('job-retrain-ranker');
  static const TaskId publishDocs = TaskId('job-publish-docs');
}

abstract final class GalleryRunIds {
  static const RunId release42 = RunId('run-release-42');
  static const RunId release41 = RunId('run-release-41');
  static const RunId writeApiDocs1 = RunId('run-write-api-docs-1');
  static const RunId renameBillingModule1 = RunId(
    'run-rename-billing-module-1',
  );
}

abstract final class GalleryApprovalIds {
  static const ApprovalId pushRelease = ApprovalId('approval-push-release');
  static const ApprovalId signTrainRanker = ApprovalId(
    'approval-sign-train-ranker',
  );
  static const ApprovalId pushBillingRename = ApprovalId(
    'approval-push-billing-rename',
  );
}
