import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/qr_code_scanner.dart';
import 'package:agent_orchestration/data/workspace_choice_store.dart';

const Duration _serverRetryInterval = Duration(seconds: 30);
const Duration _pairingPollInterval = Duration(seconds: 2);
const Duration _draftPollInterval = Duration(seconds: 1);
const Duration _livePollInterval = Duration(seconds: 1);
const Duration _loginTerminalPollInterval = Duration(milliseconds: 300);
const List<String> _labelsOfAClientOnlyNode = <String>[];

final class NodeDependencies {
  const NodeDependencies({required this.app, required this.synchronization});

  final AppDependencies app;
  final NodeSynchronization synchronization;
}

NodeDependencies buildNodeDependencies({
  required NodeCommandChannel channel,
  required Clock clock,
  required QrCodeScanner qrCodeScanner,
  required FolderPicker folderPicker,
  required WorkspaceChoiceStore workspaceChoiceStore,
}) {
  final NodeBackedWorkspaceRepository workspaceRepository =
      NodeBackedWorkspaceRepository(
        channel: channel,
        clock: clock,
        retryInterval: _serverRetryInterval,
        choiceStore: workspaceChoiceStore,
      );
  final NodeBackedProjectRepository projectRepository =
      NodeBackedProjectRepository(
        channel: channel,
        workspaceRepository: workspaceRepository,
      );
  final NodeBackedWorkflowRepository workflowRepository =
      NodeBackedWorkflowRepository(
        channel: channel,
        workspaceRepository: workspaceRepository,
        draftPollInterval: _draftPollInterval,
      );
  final NodeBackedSkillRepository skillRepository = NodeBackedSkillRepository(
    channel: channel,
    workspaceRepository: workspaceRepository,
  );
  final NodeBackedRuleRepository ruleRepository = NodeBackedRuleRepository(
    channel: channel,
    workspaceRepository: workspaceRepository,
  );
  final NodeBackedDeviceRepository deviceRepository =
      NodeBackedDeviceRepository(channel: channel);
  final NodeBackedJobRepository jobRepository = NodeBackedJobRepository(
    channel: channel,
    workspaceRepository: workspaceRepository,
    clock: clock,
  );
  final NodeBackedTaskRepository taskRepository = NodeBackedTaskRepository(
    channel: channel,
    workspaceRepository: workspaceRepository,
    livePollInterval: _livePollInterval,
    jobRepository: jobRepository,
  );
  final NodeBackedRunnerRepository runnerRepository =
      NodeBackedRunnerRepository(
        channel: channel,
        workspaceRepository: workspaceRepository,
      );
  final NodeBackedApprovalRepository approvalRepository =
      NodeBackedApprovalRepository(channel: channel);
  final NodeBackedAuditRepository auditRepository = NodeBackedAuditRepository(
    channel: channel,
  );

  final AppDependencies app = AppDependencies(
    clock: clock,
    taskRepository: taskRepository,
    jobRepository: jobRepository,
    chatRepository: NodeBackedChatRepository(
      channel: channel,
      runSource: taskRepository,
      workspaceRepository: workspaceRepository,
    ),
    approvalRepository: approvalRepository,
    projectRepository: projectRepository,
    workspaceRepository: workspaceRepository,
    workflowRepository: workflowRepository,
    skillRepository: skillRepository,
    ruleRepository: ruleRepository,
    runnerRepository: runnerRepository,
    agentLoginRepository: NodeBackedAgentLoginRepository(
      channel: channel,
      pollInterval: _loginTerminalPollInterval,
    ),
    deviceRepository: deviceRepository,
    pairingRepository: NodeBackedPairingRepository(
      channel: channel,
      clock: clock,
      pollInterval: _pairingPollInterval,
      runnerLabels: _labelsOfAClientOnlyNode,
    ),
    auditRepository: auditRepository,
    fileRepository: NodeBackedFileRepository(channel: channel),
    itemDraftRepository: NodeBackedItemDraftRepository(
      channel: channel,
      workspaceRepository: workspaceRepository,
      pollInterval: _draftPollInterval,
    ),
    qrCodeScanner: qrCodeScanner,
    folderPicker: folderPicker,
  );
  final NodeSynchronization synchronization = NodeSynchronization(
    channel: channel,
    repositoriesInLoadOrder: <NodeSynchronized>[
      workspaceRepository,
      deviceRepository,
      projectRepository,
      workflowRepository,
      skillRepository,
      ruleRepository,
      taskRepository,
      jobRepository,
      runnerRepository,
      approvalRepository,
      auditRepository,
    ],
    retryDelay: _serverRetryInterval,
    recheckAppServer: workspaceRepository.retryAppServer,
  );
  return NodeDependencies(app: app, synchronization: synchronization);
}
