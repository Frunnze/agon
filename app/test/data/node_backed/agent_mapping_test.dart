import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

void main() {
  test('test_map_agent_kind_to_node_property_round_trips', () {
    for (final node.AgentKind wire in node.AgentKind.values) {
      final AgentKind kind = mapAgentKindFromNode(wire);
      expect(mapAgentKindToNode(kind), wire);
      expect(kind.name, wire.name);
    }
  });

  test('test_map_agent_kind_from_node_property_is_one_to_one', () {
    final Set<AgentKind> kinds = <AgentKind>{
      for (final node.AgentKind wire in node.AgentKind.values)
        mapAgentKindFromNode(wire),
    };
    expect(kinds, AgentKind.values.toSet());
  });

  test('test_map_approval_policy_to_node_property_round_trips', () {
    for (final node.ApprovalPolicy wire in node.ApprovalPolicy.values) {
      final ApprovalPolicy policy = mapApprovalPolicyFromNode(wire);
      expect(mapApprovalPolicyToNode(policy), wire);
      expect(policy.name, wire.name);
    }
  });

  test('test_map_approval_policy_from_node_property_is_one_to_one', () {
    final Set<ApprovalPolicy> policies = <ApprovalPolicy>{
      for (final node.ApprovalPolicy wire in node.ApprovalPolicy.values)
        mapApprovalPolicyFromNode(wire),
    };
    expect(policies, ApprovalPolicy.values.toSet());
  });
}
