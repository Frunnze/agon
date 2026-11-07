import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/node_wire_names.dart';
import '../../../bridge/support/random_catalog_json.dart';
import '../../../support/random_inputs.dart';
import '../support/node_enum_mapping_properties.dart';

const List<ApprovalPolicy?> _optionalPolicies = <ApprovalPolicy?>[
  null,
  ApprovalPolicy.askBeforeRiskyActions,
  ApprovalPolicy.neverAsk,
];

node.ApprovalPolicy? _decodeOptionalPolicy(Object? json) {
  if (json == null) {
    return null;
  }
  return node.ApprovalPolicy.decode(json);
}

void main() {
  testEnumMappingFromNodeProperties(
    const EnumMappingFromNode<node.AgentKind, AgentKind>(
      functionName: 'map_agent_kind_from_node',
      seed: 71201,
      rustWireNames: nodeAgentKinds,
      decodeNode: node.AgentKind.decode,
      modelValues: AgentKind.values,
      mapFromNode: mapAgentKindFromNode,
    ),
  );

  testEnumMappingToNodeProperties(
    const EnumMappingToNode<node.AgentKind, AgentKind>(
      functionName: 'map_agent_kind_to_node',
      rustWireNames: nodeAgentKinds,
      nodeValues: node.AgentKind.values,
      modelValues: AgentKind.values,
      mapToNode: mapAgentKindToNode,
      mapFromNode: mapAgentKindFromNode,
    ),
  );

  testEnumMappingFromNodeProperties(
    const EnumMappingFromNode<node.ApprovalPolicy, ApprovalPolicy>(
      functionName: 'map_approval_policy_from_node',
      seed: 71203,
      rustWireNames: nodeApprovalPolicies,
      decodeNode: node.ApprovalPolicy.decode,
      modelValues: ApprovalPolicy.values,
      mapFromNode: mapApprovalPolicyFromNode,
    ),
  );

  testEnumMappingToNodeProperties(
    const EnumMappingToNode<node.ApprovalPolicy, ApprovalPolicy>(
      functionName: 'map_approval_policy_to_node',
      rustWireNames: nodeApprovalPolicies,
      nodeValues: node.ApprovalPolicy.values,
      modelValues: ApprovalPolicy.values,
      mapToNode: mapApprovalPolicyToNode,
      mapFromNode: mapApprovalPolicyFromNode,
    ),
  );

  test('test_map_optional_approval_policy_from_node_property_'
      'missing_policy_stays_missing', () {
    final Random random = seededRandom(71205);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? policyJson = randomOptionalApprovalPolicyJson(random);

      final ApprovalPolicy? policy = mapOptionalApprovalPolicyFromNode(
        _decodeOptionalPolicy(policyJson),
      );

      expect(policy == null, policyJson == null);
    }
  });

  test('test_map_optional_approval_policy_from_node_property_'
      'agrees_with_the_required_mapping', () {
    final Random random = seededRandom(71206);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ApprovalPolicy wire = pickOne(
        random,
        node.ApprovalPolicy.values,
      );

      expect(
        mapOptionalApprovalPolicyFromNode(wire),
        mapApprovalPolicyFromNode(wire),
      );
    }
  });

  test('test_map_optional_approval_policy_from_node_property_'
      'keeps_the_meaning_of_the_rust_wire_name', () {
    final Random random = seededRandom(71207);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String wireName = pickOne(random, nodeApprovalPolicies);

      final ApprovalPolicy? policy = mapOptionalApprovalPolicyFromNode(
        node.ApprovalPolicy.decode(wireName),
      );

      expect(policy?.name, writeCodeNameOfWireName(wireName));
    }
  });

  test('test_map_optional_approval_policy_to_node_property_'
      'is_undone_by_mapping_back', () {
    final Random random = seededRandom(71208);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalPolicy? policy = pickOne(random, _optionalPolicies);

      final node.ApprovalPolicy? wire = mapOptionalApprovalPolicyToNode(
        policy,
      );

      expect(mapOptionalApprovalPolicyFromNode(wire), policy);
    }
  });

  test('test_map_optional_approval_policy_to_node_property_'
      'missing_policy_stays_missing', () {
    final Random random = seededRandom(71209);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalPolicy? policy = pickOne(random, _optionalPolicies);

      final node.ApprovalPolicy? wire = mapOptionalApprovalPolicyToNode(
        policy,
      );

      expect(wire == null, policy == null);
    }
  });

  test('test_map_optional_approval_policy_to_node_property_'
      'writes_the_rust_wire_name_of_the_same_meaning', () {
    for (final ApprovalPolicy policy in ApprovalPolicy.values) {
      final String? wireName = mapOptionalApprovalPolicyToNode(policy)
          ?.wireName;
      final String requiredWireName = mapApprovalPolicyToNode(policy).wireName;

      expect(wireName, requiredWireName);
      expect(nodeApprovalPolicies, contains(wireName));
      expect(writeCodeNameOfWireName(requiredWireName), policy.name);
    }
  });
}
