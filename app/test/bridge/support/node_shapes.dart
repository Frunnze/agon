import 'package:agent_orchestration/bridge/codecs/drafting_task_views.dart';
import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/approval_views.dart';
import 'package:agent_orchestration/bridge/codecs/audit_values.dart';
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart';
import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_progress_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';
import 'package:agent_orchestration/bridge/codecs/server_group_values.dart';
import 'package:agent_orchestration/bridge/codecs/skill_change_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_views.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';

import 'node_json_primitives.dart';
import 'random_account_json.dart';
import 'random_catalog_json.dart';
import 'random_run_json.dart';
import 'random_work_json.dart';

typedef NodeValueDecoder = JsonEncodable Function(Object? json);

final class NodeShape {
  const NodeShape(this.decoderName, this.buildJson, this.decode);

  final String decoderName;
  final NodeJsonBuilder buildJson;
  final NodeValueDecoder decode;
}

const List<NodeShape> nodeShapes = <NodeShape>[
  NodeShape('device_from_json', randomDeviceJson, Device.fromJson),
  NodeShape('runner_from_json', randomRunnerJson, Runner.fromJson),
  NodeShape(
    'runner_target_from_json',
    randomRunnerTargetJson,
    RunnerTarget.fromJson,
  ),
  NodeShape('workspace_from_json', randomWorkspaceJson, Workspace.fromJson),
  NodeShape('repository_from_json', randomRepositoryJson, Repository.fromJson),
  NodeShape('project_from_json', randomProjectJson, Project.fromJson),
  NodeShape(
    'workspace_scope_from_json',
    randomWorkspaceScopeJson,
    WorkspaceScope.fromJson,
  ),
  NodeShape(
    'project_scope_from_json',
    randomProjectScopeJson,
    ProjectScope.fromJson,
  ),
  NodeShape('scope_from_json', randomScopeJson, Scope.fromJson),
  NodeShape('skill_from_json', randomSkillJson, Skill.fromJson),
  NodeShape(
    'skill_change_origin_from_json',
    randomSkillChangeOriginJson,
    SkillChangeOrigin.fromJson,
  ),
  NodeShape(
    'skill_change_from_json',
    randomSkillChangeJson,
    SkillChange.fromJson,
  ),
  NodeShape('rule_from_json', randomRuleJson, Rule.fromJson),
  NodeShape(
    'agents_markdown_view_from_json',
    randomAgentsMarkdownJson,
    AgentsMarkdownView.fromJson,
  ),
  NodeShape(
    'device_view_from_json',
    randomDeviceViewJson,
    DeviceView.fromJson,
  ),
  NodeShape(
    'workspace_view_from_json',
    randomWorkspaceViewJson,
    WorkspaceView.fromJson,
  ),
  NodeShape(
    'project_view_from_json',
    randomProjectViewJson,
    ProjectView.fromJson,
  ),
  NodeShape(
    'runners_view_from_json',
    randomRunnersViewJson,
    RunnersView.fromJson,
  ),
  NodeShape(
    'canvas_position_from_json',
    randomCanvasPositionJson,
    CanvasPosition.fromJson,
  ),
  NodeShape(
    'workflow_agent_from_json',
    randomWorkflowAgentJson,
    WorkflowAgent.fromJson,
  ),
  NodeShape('workflow_from_json', randomWorkflowJson, Workflow.fromJson),
  NodeShape('diff_line_from_json', randomDiffLineJson, DiffLine.fromJson),
  NodeShape(
    'workflow_view_from_json',
    randomWorkflowViewJson,
    WorkflowView.fromJson,
  ),
  NodeShape(
    'draft_status_from_json',
    randomDraftStatusJson,
    DraftStatus.fromJson,
  ),
  NodeShape('task_doer_from_json', randomTaskDoerJson, TaskDoer.fromJson),
  NodeShape('schedule_from_json', randomScheduleJson, Schedule.fromJson),
  NodeShape('task_from_json', randomTaskJson, Task.fromJson),
  NodeShape(
    'workflow_agent_task_view_from_json',
    randomWorkflowAgentTaskJson,
    WorkflowAgentTaskView.fromJson,
  ),
  NodeShape('run_step_from_json', randomRunStepJson, RunStep.fromJson),
  NodeShape('log_line_from_json', randomLogLineJson, LogLine.fromJson),
  NodeShape(
    'chat_message_from_json',
    randomChatMessageJson,
    ChatMessage.fromJson,
  ),
  NodeShape('run_from_json', randomRunJson, Run.fromJson),
  NodeShape(
    'run_progress_from_json',
    randomRunProgressJson,
    RunProgress.fromJson,
  ),
  NodeShape('run_view_from_json', randomRunViewJson, RunView.fromJson),
  NodeShape('tasks_view_from_json', randomTasksViewJson, TasksView.fromJson),
  NodeShape('job_view_from_json', randomJobViewJson, JobView.fromJson),
  NodeShape(
    'approval_request_from_json',
    randomApprovalRequestJson,
    ApprovalRequest.fromJson,
  ),
  NodeShape(
    'approvals_view_from_json',
    randomApprovalsViewJson,
    ApprovalsView.fromJson,
  ),
  NodeShape(
    'account_summary_from_json',
    randomAccountSummaryJson,
    AccountSummary.fromJson,
  ),
  NodeShape(
    'server_health_view_from_json',
    randomServerHealthJson,
    ServerHealthView.fromJson,
  ),
  NodeShape(
    'pending_join_from_json',
    randomPendingJoinJson,
    PendingJoin.fromJson,
  ),
  NodeShape(
    'status_view_from_json',
    randomStatusViewJson,
    StatusView.fromJson,
  ),
  NodeShape(
    'pairing_request_screen_from_json',
    randomPairingRequestScreenJson,
    PairingRequestScreen.fromJson,
  ),
  NodeShape(
    'join_status_view_from_json',
    randomJoinStatusJson,
    JoinStatusView.fromJson,
  ),
  NodeShape(
    'change_notification_from_json',
    randomChangeNotificationJson,
    ChangeNotification.fromJson,
  ),
  NodeShape(
    'events_response_from_json',
    randomEventsResponseJson,
    EventsResponse.fromJson,
  ),
  NodeShape('audit_view_from_json', randomAuditViewJson, AuditView.fromJson),
  NodeShape(
    'agent_connection_from_json',
    randomAgentConnectionJson,
    AgentConnection.fromJson,
  ),
  NodeShape(
    'workflow_signature_from_json',
    randomWorkflowSignatureJson,
    WorkflowSignature.fromJson,
  ),
  NodeShape(
    'schedule_time_from_json',
    randomScheduleTimeJson,
    ScheduleTime.fromJson,
  ),
  NodeShape(
    'task_summary_from_json',
    randomTaskSummaryJson,
    TaskSummary.fromJson,
  ),
  NodeShape('task_view_from_json', randomTaskViewJson, TaskView.fromJson),
  NodeShape(
    'run_failure_from_json',
    randomRunFailureJson,
    RunFailure.fromJson,
  ),
  NodeShape(
    'current_step_from_json',
    randomCurrentStepJson,
    CurrentStep.fromJson,
  ),
  NodeShape(
    'approval_action_from_json',
    randomApprovalActionJson,
    ApprovalAction.fromJson,
  ),
  NodeShape(
    'signed_decision_from_json',
    randomSignedDecisionJson,
    SignedDecision.fromJson,
  ),
  NodeShape(
    'approval_view_from_json',
    randomApprovalViewJson,
    ApprovalView.fromJson,
  ),
  NodeShape(
    'skill_change_view_from_json',
    randomSkillChangeViewJson,
    SkillChangeView.fromJson,
  ),
  NodeShape(
    'runner_summary_from_json',
    randomRunnerSummaryJson,
    RunnerSummary.fromJson,
  ),
  NodeShape(
    'runner_view_from_json',
    randomRunnerViewJson,
    RunnerView.fromJson,
  ),
  NodeShape(
    'joining_device_from_json',
    randomJoiningDeviceJson,
    JoiningDevice.fromJson,
  ),
  NodeShape(
    'change_topic_from_json',
    randomChangeTopicJson,
    ChangeTopic.fromJson,
  ),
  NodeShape(
    'audit_entry_view_from_json',
    randomAuditEntryJson,
    AuditEntryView.fromJson,
  ),
  NodeShape(
    'app_server_view_from_json',
    randomAppServerJson,
    AppServerView.fromJson,
  ),
  NodeShape(
    'app_servers_view_from_json',
    randomAppServersJson,
    AppServersView.fromJson,
  ),
];
