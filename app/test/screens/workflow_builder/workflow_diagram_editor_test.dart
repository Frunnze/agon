import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/screens/workflow_builder/workflow_diagram_editor.dart';

import '../../support/random_inputs.dart';
import '../../support/workflow_repositories.dart';

const WorkflowId _workflowId = GalleryWorkflowIds.featurePipeline;
const double _largestCanvasOffset = 2000;

final class _EditorBench {
  _EditorBench()
    : repository = buildGalleryWorkflowRepository(),
      editor = WorkflowDiagramEditor(
        workflowRepository: buildGalleryWorkflowRepository(),
        workflowId: _workflowId,
      );

  _EditorBench.sharing(this.repository)
    : editor = WorkflowDiagramEditor(
        workflowRepository: repository,
        workflowId: _workflowId,
      );

  final FakeWorkflowRepository repository;
  final WorkflowDiagramEditor editor;

  Workflow read() => repository.findWorkflow(_workflowId);
}

_EditorBench _openBench() {
  return _EditorBench.sharing(buildGalleryWorkflowRepository());
}

CanvasPosition _randomPosition(Random random) {
  return CanvasPosition(
    horizontal: random.nextDouble() * _largestCanvasOffset,
    vertical: random.nextDouble() * _largestCanvasOffset,
  );
}

List<WorkflowAgent> _othersThan(Workflow workflow, WorkflowAgentId agentId) {
  final List<WorkflowAgent> others = <WorkflowAgent>[];
  for (final WorkflowAgent agent in workflow.agents) {
    if (agent.id != agentId) {
      others.add(agent);
    }
  }
  return others;
}

AgentConnection _connectionInto(WorkflowAgent from, WorkflowAgent to) {
  return AgentConnection(
    from: from.id,
    to: to.id,
    condition: null,
    roundLimit: null,
  );
}

Future<AgentConnection> _connectNewStep(
  Random random,
  _EditorBench bench,
) async {
  final WorkflowAgent source = pickOne(random, bench.read().agents);
  final WorkflowAgent blank = buildBlankAgent(bench.read());
  await bench.editor.addStep(blank);
  final AgentConnection connection = _connectionInto(source, blank);
  await bench.editor.connect(connection);
  return connection;
}

void main() {
  test('test_add_step_property_the_blank_step_joins_once', () async {
    final Random random = seededRandom(7501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final Workflow before = bench.read();
      final WorkflowAgent blank = random.nextBool()
          ? buildBlankAgent(before)
          : buildBlankPersonStep(before);

      await bench.editor.addStep(blank);

      final Workflow after = bench.read();
      expect(after.agents.length, before.agents.length + 1);
      expect(after.findAgent(blank.id), blank);
    }
  });

  test('test_add_step_property_leaves_the_other_steps_alone', () async {
    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final Workflow before = bench.read();
      final WorkflowAgent blank = buildBlankAgent(before);

      await bench.editor.addStep(blank);

      final Workflow after = bench.read();
      expect(_othersThan(after, blank.id), before.agents);
      expect(after.connections, before.connections);
    }
  });

  test('test_add_step_property_repeated_steps_all_stay', () async {
    final Random random = seededRandom(7503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final int countBefore = bench.read().agents.length;
      final int stepCount = 1 + random.nextInt(4);

      for (int j = 0; j < stepCount; j += 1) {
        await bench.editor.addStep(buildBlankAgent(bench.read()));
      }

      final Set<WorkflowAgentId> ids = <WorkflowAgentId>{
        for (final WorkflowAgent agent in bench.read().agents) agent.id,
      };
      expect(ids, hasLength(countBefore + stepCount));
    }
  });

  test('test_change_agent_property_the_new_settings_are_kept', () async {
    final Random random = seededRandom(7504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final WorkflowAgent agent = pickOne(random, bench.read().agents);
      final WorkflowAgent changed = agent.copyWith(
        task: 'task ${randomWordPhrase(random)}',
        kind: pickOne(random, AgentKind.values),
      );

      await bench.editor.changeAgent(changed);

      expect(bench.read().findAgent(agent.id), changed);
    }
  });

  test('test_change_agent_property_other_steps_stay', () async {
    final Random random = seededRandom(7505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final Workflow before = bench.read();
      final WorkflowAgent agent = pickOne(random, before.agents);

      await bench.editor.changeAgent(agent.copyWith(task: 'other'));

      final Workflow after = bench.read();
      expect(_othersThan(after, agent.id), _othersThan(before, agent.id));
      expect(after.agents.length, before.agents.length);
    }
  });

  test('test_change_agent_property_keeps_every_connection', () async {
    final Random random = seededRandom(7506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final Workflow before = bench.read();
      final WorkflowAgent agent = pickOne(random, before.agents);

      await bench.editor.changeAgent(agent.copyWith(name: 'renamed-$i'));

      expect(bench.read().connections, before.connections);
    }
  });

  test('test_move_agent_property_lands_where_dropped', () async {
    final Random random = seededRandom(7507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final WorkflowAgent agent = pickOne(random, bench.read().agents);
      final CanvasPosition position = _randomPosition(random);

      await bench.editor.moveAgent(agent.id, position);

      expect(bench.read().findAgent(agent.id).position, position);
    }
  });

  test('test_move_agent_property_other_steps_do_not_move', () async {
    final Random random = seededRandom(7508);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final Workflow before = bench.read();
      final WorkflowAgent agent = pickOne(random, before.agents);

      await bench.editor.moveAgent(agent.id, _randomPosition(random));

      expect(
        _othersThan(bench.read(), agent.id),
        _othersThan(before, agent.id),
      );
    }
  });

  test('test_move_agent_property_moving_back_restores_the_design', () async {
    final Random random = seededRandom(7509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final Workflow before = bench.read();
      final WorkflowAgent agent = pickOne(random, before.agents);
      final CanvasPosition start = agent.position;

      await bench.editor.moveAgent(agent.id, _randomPosition(random));
      await bench.editor.moveAgent(agent.id, start);

      expect(hasSameDesign(bench.read(), before), isTrue);
    }
  });

  test('test_connect_property_the_connection_is_added', () async {
    final Random random = seededRandom(7510);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();

      final AgentConnection connection = await _connectNewStep(random, bench);

      expect(bench.read().connections, contains(connection));
    }
  });

  test('test_connect_property_adds_exactly_one_connection', () async {
    final Random random = seededRandom(7511);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final int countBefore = bench.read().connections.length;

      await _connectNewStep(random, bench);

      expect(bench.read().connections.length, countBefore + 1);
    }
  });

  test('test_connect_property_refuses_a_step_joined_to_itself', () async {
    final Random random = seededRandom(7512);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final Workflow before = bench.read();
      final WorkflowAgent agent = pickOne(random, before.agents);

      expect(
        () => bench.editor.connect(_connectionInto(agent, agent)),
        throwsArgumentError,
      );
      expect(bench.read().connections, before.connections);
    }
  });

  test('test_change_connection_property_the_new_rule_is_kept', () async {
    final Random random = seededRandom(7513);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final AgentConnection added = await _connectNewStep(random, bench);
      final AgentConnection changed = AgentConnection(
        from: added.from,
        to: added.to,
        condition: 'passed',
        roundLimit: null,
      );

      await bench.editor.changeConnection(changed);

      expect(findConnection(bench.read(), changed), changed);
    }
  });

  test('test_change_connection_property_keeps_the_count', () async {
    final Random random = seededRandom(7514);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final AgentConnection added = await _connectNewStep(random, bench);
      final int countBefore = bench.read().connections.length;

      await bench.editor.changeConnection(added);

      expect(bench.read().connections.length, countBefore);
    }
  });

  test('test_change_connection_property_keeps_every_step', () async {
    final Random random = seededRandom(7515);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final AgentConnection added = await _connectNewStep(random, bench);
      final List<WorkflowAgent> agentsBefore = bench.read().agents;

      await bench.editor.changeConnection(added);

      expect(bench.read().agents, agentsBefore);
    }
  });

  test('test_remove_connection_property_the_connection_is_gone', () async {
    final Random random = seededRandom(7516);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final AgentConnection added = await _connectNewStep(random, bench);

      await bench.editor.removeConnection(added);

      expect(bench.read().connections, isNot(contains(added)));
    }
  });

  test('test_remove_connection_property_drops_exactly_one', () async {
    final Random random = seededRandom(7517);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final AgentConnection added = await _connectNewStep(random, bench);
      final int countBefore = bench.read().connections.length;

      await bench.editor.removeConnection(added);

      expect(bench.read().connections.length, countBefore - 1);
    }
  });

  test('test_remove_connection_property_keeps_every_step', () async {
    final Random random = seededRandom(7518);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final AgentConnection added = await _connectNewStep(random, bench);
      final List<WorkflowAgent> agentsBefore = bench.read().agents;

      await bench.editor.removeConnection(added);

      expect(bench.read().agents, agentsBefore);
    }
  });

  test('test_remove_agent_property_the_step_is_gone', () async {
    final Random random = seededRandom(7519);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final WorkflowAgent agent = pickOne(random, bench.read().agents);

      await bench.editor.removeAgent(agent.id);

      expect(bench.read().findAgentIfPresent(agent.id), isNull);
    }
  });

  test('test_remove_agent_property_no_connection_touches_it', () async {
    final Random random = seededRandom(7520);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final WorkflowAgent agent = pickOne(random, bench.read().agents);

      await bench.editor.removeAgent(agent.id);

      for (final AgentConnection connection in bench.read().connections) {
        expect(connection.from, isNot(agent.id));
        expect(connection.to, isNot(agent.id));
      }
    }
  });

  test('test_remove_agent_property_keeps_the_other_steps', () async {
    final Random random = seededRandom(7521);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _openBench();
      final Workflow before = bench.read();
      final WorkflowAgent agent = pickOne(random, before.agents);

      await bench.editor.removeAgent(agent.id);

      expect(bench.read().agents, _othersThan(before, agent.id));
    }
  });

  test('test_workflow_diagram_editor_property_edits_one_workflow', () async {
    final Random random = seededRandom(7522);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EditorBench bench = _EditorBench();
      final Workflow untouched = bench.read();
      final WorkflowAgent agent = pickOne(random, untouched.agents);

      await bench.editor.moveAgent(agent.id, _randomPosition(random));

      expect(bench.read(), same(untouched));
    }
  });
}
