import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

void main() {
  test('test_build_blank_agent_property_new_id_and_name', () {
    final Random random = seededRandom(8201);

    for (int i = 0; i < propertyIterations; i += 1) {
      Workflow workflow = randomAcyclicWorkflow(random);
      final int additions = 1 + random.nextInt(4);

      for (int step = 0; step < additions; step += 1) {
        final WorkflowAgent blank = buildBlankAgent(workflow);
        final bool isKnownId = workflow.agents.any(
          (WorkflowAgent agent) => agent.id == blank.id,
        );
        final bool isKnownName = workflow.agents.any(
          (WorkflowAgent agent) => agent.name == blank.name,
        );

        expect(isKnownId, isFalse);
        expect(isKnownName, isFalse);
        expect(blank.name, startsWith('new-agent'));
        expect(blank.kind, isNull);
        expect(blank.task, isEmpty);
        expect(blank.runsOn, const AnyFreeRunner());
        expect(blank.approvalPolicy, isNull);
        workflow = addAgent(workflow, blank);
      }
    }
  });

  test('test_build_blank_agent_property_id_is_a_uuid_the_node_accepts', () {
    final Random random = seededRandom(8207);
    final RegExp uuidShape = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      Workflow workflow = randomAcyclicWorkflow(random);
      final int additions = 1 + random.nextInt(4);

      for (int step = 0; step < additions; step += 1) {
        final WorkflowAgent blank = buildBlankAgent(workflow);

        expect(blank.id.value, matches(uuidShape));
        workflow = addAgent(workflow, blank);
      }
    }
  });

  test('test_place_below_agents_property_lower_than_every_agent', () {
    final Random random = seededRandom(8202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomAgents(random);
      final CanvasPosition position = placeBelowAgents(agents);

      for (final WorkflowAgent agent in agents) {
        expect(position.vertical, greaterThan(agent.position.vertical));
      }
      expect(position.horizontal, greaterThanOrEqualTo(0));
    }
  });

  test('place below agents follows the gallery new agent', () {
    final Workflow pipeline = galleryWorkflows[2];
    final CanvasPosition position = placeBelowAgents(pipeline.agents);

    expect(position.horizontal, 92);
    expect(position.vertical, 560);
  });

  test('test_find_free_agent_name_property_unused_and_prefixed', () {
    final Random random = seededRandom(8203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final String baseName = pickOne(random, <String>['agent', 'new-agent']);
      final String name = findFreeAgentName(workflow, baseName);

      expect(name, startsWith(baseName));
      expect(
        workflow.agents.map((WorkflowAgent agent) => agent.name),
        isNot(contains(name)),
      );
    }
  });

  test('test_add_agent_property_rejects_known_ids', () {
    final Random random = seededRandom(8204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent known = pickOne(random, workflow.agents);

      expect(() => addAgent(workflow, known), throwsArgumentError);
    }
  });

  test('test_replace_agent_property_only_that_agent_changes', () {
    final Random random = seededRandom(8205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent chosen = pickOne(random, workflow.agents);
      final WorkflowAgent renamed = chosen.copyWith(task: randomText(random));
      final Workflow changed = replaceAgent(workflow, renamed);

      expect(changed.agents.length, workflow.agents.length);
      expect(changed.connections, workflow.connections);
      expect(changed.findAgent(chosen.id).task, renamed.task);
      for (int index = 0; index < workflow.agents.length; index += 1) {
        if (workflow.agents[index].id != chosen.id) {
          expect(changed.agents[index], same(workflow.agents[index]));
        }
      }
    }
  });

  test('test_remove_agent_property_drops_its_connections', () {
    final Random random = seededRandom(8206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent removed = pickOne(random, workflow.agents);
      final Workflow remaining = removeAgent(workflow, removed.id);

      expect(remaining.agents.length, workflow.agents.length - 1);
      for (final AgentConnection connection in remaining.connections) {
        expect(connection.from, isNot(removed.id));
        expect(connection.to, isNot(removed.id));
      }
      final int untouched = workflow.connections
          .where(
            (AgentConnection connection) =>
                connection.from != removed.id && connection.to != removed.id,
          )
          .length;
      expect(remaining.connections.length, untouched);
    }
  });

  test('test_has_same_design_property_rebuilt_unsigned_copies_match', () {
    final Random random = seededRandom(8208);
    final List<Workflow> workflows = <Workflow>[
      galleryWorkflows.first,
      for (int i = 0; i < propertyIterations; i += 1)
        randomAcyclicWorkflow(random),
    ];

    for (final Workflow workflow in workflows) {
      final Workflow rebuilt = Workflow(
        id: workflow.id,
        name: workflow.name,
        availability: workflow.availability,
        agents: <WorkflowAgent>[
          for (final WorkflowAgent agent in workflow.agents)
            agent.copyWith(position: copyPosition(agent.position)),
        ],
        connections: List<AgentConnection>.of(workflow.connections),
        signature: null,
      );

      expect(hasSameDesign(rebuilt, workflow), isTrue);
    }
  });

  test('test_has_same_design_property_every_edit_differs', () {
    final Random random = seededRandom(8209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final Workflow withBlank = addAgent(workflow, buildBlankAgent(workflow));
      final Workflow renamed = workflow.withName('${workflow.name}-renamed');

      expect(hasSameDesign(withBlank, workflow), isFalse);
      expect(hasSameDesign(renamed, workflow), isFalse);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent chosen = pickOne(random, workflow.agents);
      final CanvasPosition shifted = CanvasPosition(
        horizontal: chosen.position.horizontal + 1,
        vertical: chosen.position.vertical,
      );
      final Workflow moved = replaceAgent(
        workflow,
        chosen.copyWith(position: shifted),
      );
      expect(hasSameDesign(moved, workflow), isFalse);
    }
  });

  test('edits reject agents the workflow does not have', () {
    final Workflow release = galleryWorkflows.first;
    final WorkflowAgent stranger = release.agents.first.copyWith();
    const WorkflowAgentId missing = WorkflowAgentId('missing');

    expect(() => removeAgent(release, missing), throwsStateError);
    expect(
      () => replaceAgent(
        release.withGraph(agents: const [], connections: const []),
        stranger,
      ),
      throwsStateError,
    );
  });
}
