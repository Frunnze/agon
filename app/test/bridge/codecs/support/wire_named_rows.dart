import 'package:agent_orchestration/bridge/codecs/agent_login_values.dart';
import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';
import 'package:agent_orchestration/bridge/codecs/server_group_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/node_wire_names.dart';

const List<String> _nodeClaudeLogins = <String>[
  'logged_in',
  'not_logged_in',
  'not_installed',
  'unknown',
];
const List<String> _nodeAgentCredentialKinds = <String>[
  'long_lived_token',
  'api_key',
];
const List<String> _nodeLoginStates = <String>[
  'running',
  'finished',
  'failed',
];
const List<String> _nodeDraftKinds = <String>[
  'task',
  'job',
  'project',
  'skill',
  'rule',
];
const List<String> _nodePeerRelayChoices = <String>[
  'default',
  'disabled',
  'custom',
];

final class WireNamedRow {
  const WireNamedRow({
    required this.typeName,
    required this.choices,
    required this.nodeNames,
  });

  final String typeName;
  final List<WireNamed> choices;
  final List<String> nodeNames;
}

const List<WireNamedRow> codecWireNamedRows = <WireNamedRow>[
  WireNamedRow(
    typeName: 'claude_login',
    choices: ClaudeLogin.values,
    nodeNames: _nodeClaudeLogins,
  ),
  WireNamedRow(
    typeName: 'agent_credential_kind',
    choices: AgentCredentialKind.values,
    nodeNames: _nodeAgentCredentialKinds,
  ),
  WireNamedRow(
    typeName: 'login_state',
    choices: LoginState.values,
    nodeNames: _nodeLoginStates,
  ),
  WireNamedRow(
    typeName: 'approval_policy',
    choices: ApprovalPolicy.values,
    nodeNames: nodeApprovalPolicies,
  ),
  WireNamedRow(
    typeName: 'approval_decision',
    choices: ApprovalDecision.values,
    nodeNames: nodeApprovalDecisions,
  ),
  WireNamedRow(
    typeName: 'change_area',
    choices: ChangeArea.values,
    nodeNames: nodeChangeAreas,
  ),
  WireNamedRow(
    typeName: 'device_role',
    choices: DeviceRole.values,
    nodeNames: nodeDeviceRoles,
  ),
  WireNamedRow(
    typeName: 'device_kind',
    choices: DeviceKind.values,
    nodeNames: nodeDeviceKinds,
  ),
  WireNamedRow(
    typeName: 'hardware_key_kind',
    choices: HardwareKeyKind.values,
    nodeNames: nodeHardwareKeyKinds,
  ),
  WireNamedRow(
    typeName: 'runner_link',
    choices: RunnerLink.values,
    nodeNames: nodeRunnerLinks,
  ),
  WireNamedRow(
    typeName: 'draft_kind',
    choices: DraftKind.values,
    nodeNames: _nodeDraftKinds,
  ),
  WireNamedRow(
    typeName: 'skill_usage',
    choices: SkillUsage.values,
    nodeNames: nodeSkillUsages,
  ),
  WireNamedRow(
    typeName: 'skill_source',
    choices: SkillSource.values,
    nodeNames: nodeSkillSources,
  ),
  WireNamedRow(
    typeName: 'skill_improvement',
    choices: SkillImprovement.values,
    nodeNames: nodeSkillImprovements,
  ),
  WireNamedRow(
    typeName: 'repository_entry_kind',
    choices: RepositoryEntryKind.values,
    nodeNames: nodeRepositoryEntryKinds,
  ),
  WireNamedRow(
    typeName: 'chat_author',
    choices: ChatAuthor.values,
    nodeNames: nodeChatAuthors,
  ),
  WireNamedRow(
    typeName: 'step_status',
    choices: StepStatus.values,
    nodeNames: nodeStepStatuses,
  ),
  WireNamedRow(
    typeName: 'run_status',
    choices: RunStatus.values,
    nodeNames: nodeRunStatuses,
  ),
  WireNamedRow(
    typeName: 'weekday',
    choices: Weekday.values,
    nodeNames: nodeWeekdays,
  ),
  WireNamedRow(
    typeName: 'server_standing',
    choices: ServerStanding.values,
    nodeNames: nodeServerStandings,
  ),
  WireNamedRow(
    typeName: 'this_device_standing',
    choices: ThisDeviceStanding.values,
    nodeNames: nodeThisDeviceStandings,
  ),
  WireNamedRow(
    typeName: 'task_status',
    choices: TaskStatus.values,
    nodeNames: nodeTaskStatuses,
  ),
  WireNamedRow(
    typeName: 'task_start',
    choices: TaskStart.values,
    nodeNames: nodeTaskStarts,
  ),
  WireNamedRow(
    typeName: 'agent_kind',
    choices: AgentKind.values,
    nodeNames: nodeAgentKinds,
  ),
  WireNamedRow(
    typeName: 'step_kind',
    choices: StepKind.values,
    nodeNames: nodeStepKinds,
  ),
  WireNamedRow(
    typeName: 'signature_state',
    choices: SignatureState.values,
    nodeNames: nodeSignatureStates,
  ),
  WireNamedRow(
    typeName: 'diff_line_change',
    choices: DiffLineChange.values,
    nodeNames: nodeDiffChanges,
  ),
  WireNamedRow(
    typeName: 'agent_access',
    choices: AgentAccess.values,
    nodeNames: nodeAgentAccesses,
  ),
];

const List<WireNamedRow> nodeSettingWireNamedRows = <WireNamedRow>[
  WireNamedRow(
    typeName: 'container_engine_choice',
    choices: ContainerEngineChoice.values,
    nodeNames: nodeContainerEngines,
  ),
  WireNamedRow(
    typeName: 'agent_place',
    choices: AgentPlace.values,
    nodeNames: nodeAgentPlaces,
  ),
  WireNamedRow(
    typeName: 'peer_relay_choice',
    choices: PeerRelayChoice.values,
    nodeNames: _nodePeerRelayChoices,
  ),
];
