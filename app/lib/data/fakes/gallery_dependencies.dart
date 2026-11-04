import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
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
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/folders/folder_picker_choice.dart';
import 'package:agent_orchestration/scanning/camera_qr_code_scanner.dart';

const int _featurePipelineIndex = 2;
const Duration _galleryDraftStepDelay = Duration(milliseconds: 700);

AppDependencies buildGalleryDependencies() {
  final Clock clock = FixedClock(galleryNow);
  final FakeWorkflowRepository workflowRepository = FakeWorkflowRepository(
    workflows: galleryWorkflows,
    changes: galleryWorkflowChanges,
    clock: clock,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    draftTemplate: galleryWorkflows[_featurePipelineIndex],
    drafterDeviceId: GalleryDeviceIds.officeServer,
    draftStepDelay: _galleryDraftStepDelay,
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

  return AppDependencies(
    clock: clock,
    taskRepository: taskRepository,
    jobRepository: FakeJobRepository(
      taskRepository: taskRepository,
      clock: clock,
    ),
    chatRepository: FakeChatRepository(
      conversations: <Conversation>[galleryConversationAwaitingApproval],
      clock: clock,
    ),
    approvalRepository: FakeApprovalRepository(
      approvals: <ApprovalRequest>[
        ...galleryApprovals,
        galleryDeniedPushApproval,
      ],
      clock: clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
    personStepRepository: FakePersonStepRepository(
      openSteps: const <OpenPersonStep>[],
    ),
    projectRepository: FakeProjectRepository(projects: galleryProjects),
    workspaceRepository: FakeWorkspaceRepository(
      workspaces: galleryWorkspaces,
      currentWorkspaceId: GalleryWorkspaceIds.acme,
      appServerStatus: galleryAppServerStatus,
      appServerGroup: galleryAppServerGroup,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      clock: clock,
    ),
    workflowRepository: workflowRepository,
    skillRepository: FakeSkillRepository(skills: gallerySkills, clock: clock),
    ruleRepository: FakeRuleRepository(rules: galleryRules, clock: clock),
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
    ),
    auditRepository: FakeAuditRepository(
      entries: galleryAuditEntries,
      summary: ChainSummary(
        entryCount: galleryAuditEntryCount,
        headHash: galleryAuditEntries.first.hash,
      ),
    ),
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
  );
}
