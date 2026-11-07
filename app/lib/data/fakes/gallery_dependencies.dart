import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/fakes/fake_workspace_contents.dart';
import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_audit.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_files.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_item_drafts.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/folders/folder_picker_choice.dart';
import 'package:agent_orchestration/scanning/camera_qr_code_scanner.dart';

const int _featurePipelineIndex = 2;
const Duration _galleryDraftStepDelay = Duration(milliseconds: 700);

FakeWorkflowRepository _buildWorkflowRepository(Clock clock) {
  return FakeWorkflowRepository(
    workflows: galleryWorkflows,
    changes: galleryWorkflowChanges,
    clock: clock,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    draftTemplate: galleryWorkflows[_featurePipelineIndex],
    drafterDeviceId: GalleryDeviceIds.officeServer,
    draftStepDelay: _galleryDraftStepDelay,
  );
}

FakeApprovalRepository _buildApprovalRepository(Clock clock) {
  return FakeApprovalRepository(
    approvals: <ApprovalRequest>[
      ...galleryApprovals,
      galleryDeniedPushApproval,
    ],
    clock: clock,
    currentDeviceId: GalleryDeviceIds.airLaptop,
  );
}

FakeWorkspaceRepository _buildWorkspaceRepository(Clock clock) {
  return FakeWorkspaceRepository(
    workspaces: galleryWorkspaces,
    currentWorkspaceId: GalleryWorkspaceIds.acme,
    appServerStatus: galleryAppServerStatus,
    appServerGroup: galleryAppServerGroup,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    clock: clock,
  );
}

AppDependencies buildGalleryDependencies() {
  final Clock clock = FixedClock(galleryNow);
  final FakeApprovalRepository approvalRepository = _buildApprovalRepository(
    clock,
  );
  final FakeWorkflowRepository workflowRepository = _buildWorkflowRepository(
    clock,
  );

  final FakeDeviceRepository deviceRepository = FakeDeviceRepository(
    devices: galleryDevices,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    peerAddressProblem: null,
    gitlessFolderPaths: const <String>{},
  );

  final FakeTaskRepository taskRepository = FakeTaskRepository(
    tasks: <Task>[...galleryTasks, ...galleryJobs],
    runs: galleryRuns,
    clock: clock,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    workflowRepository: workflowRepository,
  );
  final FakeJobRepository jobRepository = FakeJobRepository(
    taskRepository: taskRepository,
    clock: clock,
  );
  final FakeTaskWork taskWork = FakeTaskWork(
    taskRepository: taskRepository,
    jobRepository: jobRepository,
  );
  workflowRepository.linkWork(
    taskWork: taskWork,
    approvalRepository: approvalRepository,
  );

  final FakeProjectRepository projectRepository = FakeProjectRepository(
    projects: galleryProjects,
    taskWork: taskWork,
  );
  final FakeWorkspaceRepository workspaceRepository =
      _buildWorkspaceRepository(clock);
  final FakeSkillRepository skillRepository = FakeSkillRepository(
    skills: gallerySkills,
    clock: clock,
  );
  final FakeRuleRepository ruleRepository = FakeRuleRepository(
    rules: galleryRules,
    clock: clock,
    workspaceRepository: workspaceRepository,
  );
  workspaceRepository.linkContents(
    FakeWorkspaceContents(
      projectRepository: projectRepository,
      taskWork: taskWork,
      skillRepository: skillRepository,
      ruleRepository: ruleRepository,
      workflowRepository: workflowRepository,
    ),
  );

  return AppDependencies(
    clock: clock,
    taskRepository: taskRepository,
    jobRepository: jobRepository,
    chatRepository: FakeChatRepository(
      conversations: <Conversation>[galleryConversationAwaitingApproval],
      taskRepository: taskRepository,
      clock: clock,
    ),
    approvalRepository: approvalRepository,
    personStepRepository: FakePersonStepRepository(
      openSteps: const <OpenPersonStep>[],
      taskRepository: taskRepository,
    ),
    projectRepository: projectRepository,
    workspaceRepository: workspaceRepository,
    workflowRepository: workflowRepository,
    skillRepository: skillRepository,
    ruleRepository: ruleRepository,
    runnerRepository: FakeRunnerRepository(
      runners: galleryRunners,
      thisDeviceOffers: null,
      thisRunnerProblem: null,
    ),
    agentLoginRepository: FakeAgentLoginRepository(
      status: const AgentLoginStatus(
        claudeLogin: ClaudeLogin.loggedIn,
        containerCredential: null,
      ),
    ),
    deviceRepository: deviceRepository,
    pairingRepository: FakePairingRepository(
      session: galleryPairingSession,
      request: galleryPairingRequest,
      clock: clock,
      deviceRepository: deviceRepository,
      joinOutcome: galleryPairingOutcome,
      startedPairingRendezvousProblem: null,
    ),
    auditRepository: FakeAuditRepository(entries: galleryAuditEntries),
    fileRepository: FakeFileRepository(
      sources: galleryFileSources,
      files: galleryRepositoryFiles,
    ),
    itemDraftRepository: FakeItemDraftRepository(
      drafts: buildGalleryItemDrafts(),
      drafterDeviceId: GalleryDeviceIds.officeServer,
      stepDelay: _galleryDraftStepDelay,
    ),
    qrCodeScanner: const CameraQrCodeScanner(),
    folderPicker: buildPlatformFolderPicker(defaultTargetPlatform),
    runnerPresence: null,
  );
}
