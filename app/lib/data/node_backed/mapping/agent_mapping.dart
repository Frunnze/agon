import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

AgentKind mapAgentKindFromNode(node.AgentKind kind) {
  return switch (kind) {
    node.AgentKind.claudeCode => AgentKind.claudeCode,
    node.AgentKind.codex => AgentKind.codex,
    node.AgentKind.geminiCli => AgentKind.geminiCli,
  };
}

node.AgentKind mapAgentKindToNode(AgentKind kind) {
  return switch (kind) {
    AgentKind.claudeCode => node.AgentKind.claudeCode,
    AgentKind.codex => node.AgentKind.codex,
    AgentKind.geminiCli => node.AgentKind.geminiCli,
  };
}

ApprovalPolicy mapApprovalPolicyFromNode(node.ApprovalPolicy policy) {
  return switch (policy) {
    node.ApprovalPolicy.askBeforeRiskyActions =>
      ApprovalPolicy.askBeforeRiskyActions,
    node.ApprovalPolicy.neverAsk => ApprovalPolicy.neverAsk,
  };
}

node.ApprovalPolicy mapApprovalPolicyToNode(ApprovalPolicy policy) {
  return switch (policy) {
    ApprovalPolicy.askBeforeRiskyActions =>
      node.ApprovalPolicy.askBeforeRiskyActions,
    ApprovalPolicy.neverAsk => node.ApprovalPolicy.neverAsk,
  };
}
