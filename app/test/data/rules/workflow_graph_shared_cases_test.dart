import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_inputs.dart';

const String _sharedCasesPath =
    '../rust/crates/orchestration-core/tests/fixtures/'
    'workflow_graph_cases.json';
const String _caseWorkflowId = 'shared-case-workflow';
const String _caseWorkflowName = 'shared-case';
const String _agentIdPrefix = 'shared-agent-';

class _SharedGraphCase {
  const _SharedGraphCase({
    required this.description,
    required this.workflow,
    required this.order,
    required this.isValid,
    required this.reachedFromFirst,
  });

  final String description;
  final Workflow workflow;
  final List<String> order;
  final bool isValid;
  final Set<String> reachedFromFirst;
}

Map<String, Object?> _readObject(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw FormatException('a shared graph entry is not an object: $entry');
  }
  return entry;
}

List<Object?> _readList(Object? entry) {
  if (entry is! List<Object?>) {
    throw FormatException('a shared graph entry is not a list: $entry');
  }
  return entry;
}

List<String> _readNames(Object? entry) {
  return <String>[
    for (final Object? name in _readList(entry)) name! as String,
  ];
}

WorkflowAgentId _identifyAgent(List<String> names, String name) {
  final int position = names.indexOf(name);
  if (position < 0) {
    throw FormatException('a shared graph case names no agent $name');
  }
  return WorkflowAgentId('$_agentIdPrefix$position');
}

WorkflowAgent _readAgent(Object? entry, int position) {
  final Map<String, Object?> fields = _readObject(entry);
  return WorkflowAgent(
    id: WorkflowAgentId('$_agentIdPrefix$position'),
    name: fields['name']! as String,
    stepKind: StepKind.agent,
    kind: null,
    task: '',
    runsOn: const AnyFreeRunner(),
    skills: const <SkillId>[],
    usesAutomaticSkills: false,
    approvalPolicy: null,
    position: CanvasPosition(
      horizontal: (fields['horizontal']! as num).toDouble(),
      vertical: (fields['vertical']! as num).toDouble(),
    ),
  );
}

AgentConnection _readConnection(Object? entry, List<String> names) {
  final Map<String, Object?> fields = _readObject(entry);
  return AgentConnection(
    from: _identifyAgent(names, fields['from']! as String),
    to: _identifyAgent(names, fields['to']! as String),
    condition: fields['condition'] as String?,
    roundLimit: fields['round_limit'] as int?,
  );
}

_SharedGraphCase _readSharedCase(Object? entry) {
  final Map<String, Object?> fields = _readObject(entry);
  final List<Object?> agentEntries = _readList(fields['agents']);
  final List<WorkflowAgent> agents = <WorkflowAgent>[
    for (int position = 0; position < agentEntries.length; position += 1)
      _readAgent(agentEntries[position], position),
  ];
  final List<String> names = <String>[
    for (final WorkflowAgent agent in agents) agent.name,
  ];
  final List<AgentConnection> connections = <AgentConnection>[
    for (final Object? connection in _readList(fields['connections']))
      _readConnection(connection, names),
  ];
  return _SharedGraphCase(
    description: fields['description']! as String,
    workflow: Workflow(
      id: const WorkflowId(_caseWorkflowId),
      name: _caseWorkflowName,
      availability: const AllWorkspaces(),
      agents: agents,
      connections: connections,
      signature: null,
    ),
    order: _readNames(fields['order']),
    isValid: fields['is_valid']! as bool,
    reachedFromFirst: _readNames(fields['reached_from_first']).toSet(),
  );
}

List<_SharedGraphCase> _readSharedCases() {
  final String sharedCasesText = File(_sharedCasesPath).readAsStringSync();
  return <_SharedGraphCase>[
    for (final Object? entry in _readList(jsonDecode(sharedCasesText)))
      _readSharedCase(entry),
  ];
}

List<String> _listOrderedNames(Workflow workflow) {
  return <String>[
    for (final WorkflowAgent agent in orderAgents(workflow)) agent.name,
  ];
}

Set<String> _listReachedNames(Workflow workflow) {
  final WorkflowAgent first = workflow.agents.first;
  return <String>{
    for (final WorkflowAgent agent in workflow.agents)
      if (reachesForward(workflow, from: first.id, to: agent.id)) agent.name,
  };
}

void main() {
  final List<_SharedGraphCase> sharedCases = _readSharedCases();

  test('test_order_agents_property_agrees_with_the_shared_table', () {
    for (final _SharedGraphCase sharedCase in sharedCases) {
      final List<String> names = _listOrderedNames(sharedCase.workflow);

      expect(names, sharedCase.order, reason: sharedCase.description);
    }
  });

  test('test_describe_connections_problem_property_agrees_with_table', () {
    for (final _SharedGraphCase sharedCase in sharedCases) {
      final String? problem = describeConnectionsProblem(sharedCase.workflow);

      expect(
        problem == null,
        sharedCase.isValid,
        reason: '${sharedCase.description}: $problem',
      );
    }
  });

  test('test_reaches_forward_property_agrees_with_the_shared_table', () {
    for (final _SharedGraphCase sharedCase in sharedCases) {
      final Set<String> reached = _listReachedNames(sharedCase.workflow);

      expect(
        reached,
        sharedCase.reachedFromFirst,
        reason: sharedCase.description,
      );
    }
  });

  test('test_order_agents_property_shared_table_ignores_storage_order', () {
    final Random random = seededRandom(61873);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SharedGraphCase sharedCase = pickOne(random, sharedCases);
      final Workflow workflow = sharedCase.workflow;
      final List<WorkflowAgent> shuffled = List<WorkflowAgent>.of(
        workflow.agents,
      );
      shuffled.shuffle(random);
      final Workflow reordered = workflow.withGraph(
        agents: shuffled,
        connections: workflow.connections,
      );

      final List<String> names = _listOrderedNames(reordered);
      final String? problem = describeConnectionsProblem(reordered);

      expect(names, sharedCase.order, reason: sharedCase.description);
      expect(problem == null, sharedCase.isValid);
    }
  });
}
