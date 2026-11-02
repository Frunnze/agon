import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

WorkspaceId decodeWorkspaceId(Object? json) => WorkspaceId(decodeText(json));

ProjectId decodeProjectId(Object? json) => ProjectId(decodeText(json));

DeviceId decodeDeviceId(Object? json) => DeviceId(decodeText(json));

WorkflowId decodeWorkflowId(Object? json) => WorkflowId(decodeText(json));

WorkflowAgentId decodeWorkflowAgentId(Object? json) {
  return WorkflowAgentId(decodeText(json));
}

SkillId decodeSkillId(Object? json) => SkillId(decodeText(json));

RuleId decodeRuleId(Object? json) => RuleId(decodeText(json));

TaskId decodeTaskId(Object? json) => TaskId(decodeText(json));

RunId decodeRunId(Object? json) => RunId(decodeText(json));

ApprovalId decodeApprovalId(Object? json) => ApprovalId(decodeText(json));
