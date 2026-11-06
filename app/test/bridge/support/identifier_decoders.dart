import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

final class IdentifierDecoder {
  const IdentifierDecoder(this.decoderName, this.decode);

  final String decoderName;
  final JsonValueDecoder<Object> decode;
}

const List<IdentifierDecoder> identifierDecoders = <IdentifierDecoder>[
  IdentifierDecoder('decode_workspace_id', decodeWorkspaceId),
  IdentifierDecoder('decode_project_id', decodeProjectId),
  IdentifierDecoder('decode_device_id', decodeDeviceId),
  IdentifierDecoder('decode_workflow_id', decodeWorkflowId),
  IdentifierDecoder('decode_workflow_agent_id', decodeWorkflowAgentId),
  IdentifierDecoder('decode_skill_id', decodeSkillId),
  IdentifierDecoder('decode_rule_id', decodeRuleId),
  IdentifierDecoder('decode_task_id', decodeTaskId),
  IdentifierDecoder('decode_run_id', decodeRunId),
  IdentifierDecoder('decode_approval_id', decodeApprovalId),
];
