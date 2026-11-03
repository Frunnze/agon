import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/folder_picker.dart';
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

final class AppDependencies {
  const AppDependencies({
    required this.clock,
    required this.taskRepository,
    required this.jobRepository,
    required this.chatRepository,
    required this.approvalRepository,
    required this.projectRepository,
    required this.workspaceRepository,
    required this.workflowRepository,
    required this.skillRepository,
    required this.ruleRepository,
    required this.runnerRepository,
    required this.agentLoginRepository,
    required this.deviceRepository,
    required this.pairingRepository,
    required this.auditRepository,
    required this.fileRepository,
    required this.itemDraftRepository,
    required this.qrCodeScanner,
    required this.folderPicker,
  });

  final Clock clock;
  final TaskRepository taskRepository;
  final JobRepository jobRepository;
  final ChatRepository chatRepository;
  final ApprovalRepository approvalRepository;
  final ProjectRepository projectRepository;
  final WorkspaceRepository workspaceRepository;
  final WorkflowRepository workflowRepository;
  final SkillRepository skillRepository;
  final RuleRepository ruleRepository;
  final RunnerRepository runnerRepository;
  final AgentLoginRepository agentLoginRepository;
  final DeviceRepository deviceRepository;
  final PairingRepository pairingRepository;
  final AuditRepository auditRepository;
  final FileRepository fileRepository;
  final ItemDraftRepository itemDraftRepository;
  final QrCodeScanner qrCodeScanner;
  final FolderPicker folderPicker;
}
