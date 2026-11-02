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
