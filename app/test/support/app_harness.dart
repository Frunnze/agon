import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/qr_code_scanner.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/audit_repository.dart';
import 'package:agent_orchestration/data/repository/chat_repository.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';
import 'package:agent_orchestration/data/repository/item_draft_repository.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import 'widget_harness.dart';

const Size phoneSize = Size(phoneWidth, phoneHeight);
const Size desktopSize = Size(desktopWidth, desktopHeight);
const Duration settleTime = Duration(milliseconds: 600);

AppDependencies replaceRepositories(
  AppDependencies base, {
  TaskRepository? taskRepository,
  JobRepository? jobRepository,
  ChatRepository? chatRepository,
  ApprovalRepository? approvalRepository,
  ProjectRepository? projectRepository,
  WorkspaceRepository? workspaceRepository,
  WorkflowRepository? workflowRepository,
  SkillRepository? skillRepository,
  RuleRepository? ruleRepository,
  PairingRepository? pairingRepository,
  AuditRepository? auditRepository,
  FileRepository? fileRepository,
  DeviceRepository? deviceRepository,
  RunnerRepository? runnerRepository,
  AgentLoginRepository? agentLoginRepository,
  ItemDraftRepository? itemDraftRepository,
  QrCodeScanner? qrCodeScanner,
  FolderPicker? folderPicker,
}) {
  return AppDependencies(
    clock: base.clock,
    taskRepository: taskRepository ?? base.taskRepository,
    jobRepository: jobRepository ?? base.jobRepository,
    chatRepository: chatRepository ?? base.chatRepository,
    approvalRepository: approvalRepository ?? base.approvalRepository,
    projectRepository: projectRepository ?? base.projectRepository,
    workspaceRepository: workspaceRepository ?? base.workspaceRepository,
    workflowRepository: workflowRepository ?? base.workflowRepository,
    skillRepository: skillRepository ?? base.skillRepository,
    ruleRepository: ruleRepository ?? base.ruleRepository,
    runnerRepository: runnerRepository ?? base.runnerRepository,
    agentLoginRepository: agentLoginRepository ?? base.agentLoginRepository,
    deviceRepository: deviceRepository ?? base.deviceRepository,
    pairingRepository: pairingRepository ?? base.pairingRepository,
    auditRepository: auditRepository ?? base.auditRepository,
    fileRepository: fileRepository ?? base.fileRepository,
    itemDraftRepository: itemDraftRepository ?? base.itemDraftRepository,
    qrCodeScanner: qrCodeScanner ?? base.qrCodeScanner,
    folderPicker: folderPicker ?? base.folderPicker,
  );
}

AppDependencies buildDependenciesWithoutTasks() {
  final AppDependencies base = buildGalleryDependencies();

  return replaceRepositories(
    base,
    taskRepository: FakeTaskRepository(
      tasks: const <Task>[],
      runs: const <Run>[],
      clock: base.clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      workflowRepository: base.workflowRepository,
    ),
    approvalRepository: FakeApprovalRepository(
      approvals: const <ApprovalRequest>[],
      clock: base.clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
  );
}

AppDependencies buildDependenciesWithConversation(Conversation conversation) {
  final AppDependencies base = buildGalleryDependencies();
  final Clock clock = FixedClock(galleryNow);

  return replaceRepositories(
    base,
    chatRepository: FakeChatRepository(
      conversations: <Conversation>[conversation],
      clock: clock,
    ),
    approvalRepository: FakeApprovalRepository(
      approvals: const <ApprovalRequest>[],
      clock: clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
  );
}

Future<AppNavigation> pumpApp(
  WidgetTester tester, {
  required Size size,
  required AppRoute route,
  required AppDependencies dependencies,
}) async {
  final AppNavigation navigation = AppNavigation(initialRoute: route);
  useViewSize(tester, size);
  await tester.pumpWidget(
    AgentOrchestrationApp(
      dependencies: dependencies,
      navigation: navigation,
      messengerKey: GlobalKey<ScaffoldMessengerState>(),
    ),
  );
  await tester.pump();
  await tester.pump(settleTime);
  return navigation;
}

Future<void> pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(settleTime);
  await tester.pump(settleTime);
}
