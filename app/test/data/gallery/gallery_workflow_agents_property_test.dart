import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflow_agents.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/gallery_records.dart';

const int _largestAgentCount = 8;
const int _largestRow = 40;
const double _positionTolerance = 1e-9;
const List<String> _workflowNames = <String>['release', 'flow', 'docs-sync'];

List<WorkflowAgent> _buildStackedAgents(Random random, String workflowName) {
  final int count = random.nextInt(_largestAgentCount);

  return <WorkflowAgent>[
    for (int row = 0; row < count; row += 1)
      buildGalleryAgent(
        workflowName: workflowName,
        name: 'step-$row',
        kind: pickOne(random, AgentKind.values),
        runsOn: randomRunnerTarget(random),
        position: stackedPosition(row),
      ),
  ];
}

Workflow _buildWorkflow(
  List<WorkflowAgent> agents,
  List<AgentConnection> connections,
) {
  return Workflow(
    id: const WorkflowId('workflow-under-test'),
    name: 'workflow-under-test',
    availability: const AllWorkspaces(),
    agents: agents,
    connections: connections,
    signature: null,
  );
}

void _expectPlainConnections(List<AgentConnection> connections) {
  final List<(WorkflowAgentId, WorkflowAgentId)> pairs =
      <(WorkflowAgentId, WorkflowAgentId)>[
        for (final AgentConnection connection in connections)
          (connection.from, connection.to),
      ];

  expect(hasNoRepeats(pairs), isTrue);
  for (final AgentConnection connection in connections) {
    expect(connection.condition, isNull);
    expect(connection.roundLimit, isNull);
    expect(connection.from, isNot(connection.to));
  }
}

void main() {
  test('test_build_gallery_agent_property_keeps_every_given_field', () {
    final Random random = seededRandom(68301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String workflowName = pickOne(random, _workflowNames);
      final AgentKind kind = pickOne(random, AgentKind.values);
      final RunnerTarget runsOn = randomRunnerTarget(random);
      final CanvasPosition position = stackedPosition(
        random.nextInt(_largestRow),
      );
      final List<SkillId> skills = <SkillId>[
        for (final SkillId skillId in sampleSkillIds)
          if (random.nextBool()) skillId,
      ];
      final WorkflowAgent agent = buildGalleryAgent(
        workflowName: workflowName,
        name: 'step-$i',
        kind: kind,
        runsOn: runsOn,
        position: position,
        skills: skills,
      );

      expect(agent.name, 'step-$i');
      expect(agent.kind, kind);
      expect(agent.runsOn, runsOn);
      expect(agent.position, position);
      expect(agent.skills, skills);
      expect(agent.stepKind, StepKind.agent);
      expect(agent.task, contains(workflowName));
    }
  });

  test('test_build_gallery_agent_property_distinct_steps_get_distinct_'
      'ids', () {
    final List<WorkflowAgentId> identifiers = <WorkflowAgentId>[
      for (final String workflowName in _workflowNames)
        for (int row = 0; row < _largestAgentCount; row += 1)
          buildGalleryAgent(
            workflowName: workflowName,
            name: 'step-$row',
            kind: AgentKind.codex,
            runsOn: const AnyFreeRunner(),
            position: stackedPosition(row),
          ).id,
    ];

    expect(hasNoRepeats(identifiers), isTrue);
  });

  test('test_stacked_position_property_rows_are_evenly_spaced', () {
    final Random random = seededRandom(68302);
    final double rowHeight =
        stackedPosition(1).vertical - stackedPosition(0).vertical;

    for (int i = 0; i < propertyIterations; i += 1) {
      final int row = random.nextInt(_largestRow);
      final double expected = stackedPosition(0).vertical + row * rowHeight;

      expect(
        stackedPosition(row).vertical,
        closeTo(expected, _positionTolerance),
      );
    }
  });

  test('test_stacked_position_property_stays_on_the_canvas', () {
    for (int row = 0; row < _largestRow; row += 1) {
      final CanvasPosition position = stackedPosition(row);

      expect(position.vertical, greaterThanOrEqualTo(0));
      expect(position.horizontal, greaterThanOrEqualTo(0));
    }
  });

  test('test_connect_in_order_property_builds_a_valid_chain', () {
    final Random random = seededRandom(68303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = _buildStackedAgents(random, 'flow');
      final Workflow workflow = _buildWorkflow(agents, connectInOrder(agents));
      final String? expectedProblem = agents.isEmpty ? noAgentsProblem : null;

      expect(describeWorkflowProblem(workflow), expectedProblem);
      expect(orderAgents(workflow), agents);
    }
  });

  test('test_connect_in_order_property_connections_are_plain', () {
    final Random random = seededRandom(68304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = _buildStackedAgents(random, 'flow');
      final List<WorkflowAgent> before = List<WorkflowAgent>.of(agents);

      _expectPlainConnections(connectInOrder(agents));
      expect(agents, before);
    }
  });

  test('test_connect_feature_pipeline_property_passes_the_workflow_'
      'rules', () {
    final List<AgentConnection> connections = connectFeaturePipeline();
    final Workflow workflow = _buildWorkflow(
      featurePipelineAgents,
      connections,
    );

    expect(describeWorkflowProblem(workflow), isNull);
    _expectPlainConnections(connections);
    expect(identical(connectFeaturePipeline(), connections), isFalse);
  });

  test('test_connect_feature_pipeline_property_every_step_reaches_'
      'ship', () {
    final Workflow workflow = _buildWorkflow(
      featurePipelineAgents,
      connectFeaturePipeline(),
    );
    final WorkflowAgentId ship = featurePipelineAgents.last.id;

    for (final WorkflowAgent agent in featurePipelineAgents) {
      expect(
        hasForwardPath(workflow, from: agent.id, to: ship),
        isTrue,
        reason: agent.name,
      );
    }
    expect(orderAgents(workflow).first, featurePipelineAgents.first);
  });

  test('test_feature_pipeline_agents_property_named_and_placed_apart', () {
    final List<String> names = <String>[
      for (final WorkflowAgent agent in featurePipelineAgents) agent.name,
    ];
    final List<(double, double)> spots = <(double, double)>[
      for (final WorkflowAgent agent in featurePipelineAgents)
        (agent.position.horizontal, agent.position.vertical),
    ];

    for (final String name in names) {
      expect(describeNameProblem(name), isNull);
    }
    expect(hasNoRepeats(names), isTrue);
    expect(hasNoRepeats(spots), isTrue);
  });

  test('test_gallery_runner_targets_property_resolve_to_real_runners', () {
    for (final SpecificRunner target in <SpecificRunner>[
      onOfficeServer,
      onMacStudio,
    ]) {
      expect(roleRunsTasks(findGalleryDevice(target.deviceId).role), isTrue);
    }
    final bool hasGpuRunner = galleryRunners.any(
      (Runner runner) => runner.labels.toSet().containsAll(onGpuRunner.labels),
    );

    expect(hasGpuRunner, isTrue);
  });
}
