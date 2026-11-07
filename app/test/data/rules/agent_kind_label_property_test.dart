import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/rules/agent_kind_label.dart';

import '../../support/random_inputs.dart';
import '../gallery/support/node_run_rules.dart';

final RegExp _lowercaseKebabCase = RegExp(r'^[a-z]+(-[a-z]+)*$');

void main() {
  test('test_label_agent_kind_property_matches_the_rust_labels', () {
    final Random random = seededRandom(73101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentKind kind = pickOne(random, AgentKind.values);

      expect(labelAgentKind(kind), nodeOneAgentStepNames[kind]);
    }
  });

  test('test_label_agent_kind_property_different_kinds_get_different_'
      'labels', () {
    final Random random = seededRandom(73102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentKind first = pickOne(random, AgentKind.values);
      final AgentKind second = pickOne(random, AgentKind.values);
      final bool isSameLabel = labelAgentKind(first) == labelAgentKind(second);

      expect(isSameLabel, first == second);
    }
  });

  test('test_label_agent_kind_property_is_lowercase_kebab_case', () {
    final Random random = seededRandom(73103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentKind kind = pickOne(random, AgentKind.values);

      expect(labelAgentKind(kind), matches(_lowercaseKebabCase));
    }
  });

  test('test_label_agent_kind_property_is_the_wire_name_with_dashes', () {
    final Random random = seededRandom(73104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentKind kind = pickOne(random, AgentKind.values);
      final String wireName = mapAgentKindToNode(kind).wireName;

      expect(labelAgentKind(kind), wireName.replaceAll('_', '-'));
    }
  });
}
