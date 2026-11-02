import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/presentation/skill_names.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

void main() {
  test('test_copy_with_property_untouched_fields_kept', () {
    final Random random = seededRandom(9401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent agent = randomAgent(random, i);
      final String task = randomText(random);
      final WorkflowAgent copy = agent.copyWith(task: task);

      expect(copy.id, agent.id);
      expect(copy.name, agent.name);
      expect(copy.kind, agent.kind);
      expect(copy.task, task);
      expect(copy.runsOn, agent.runsOn);
      expect(copy.skills, agent.skills);
      expect(copy.usesAutomaticSkills, agent.usesAutomaticSkills);
      expect(copy.approvalPolicy, agent.approvalPolicy);
      expect(copy.position, same(agent.position));
    }
  });

  test('test_with_graph_property_identity_and_signature_kept', () {
    final Random random = seededRandom(9402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final Workflow other = randomAcyclicWorkflow(random);
      final Workflow regraphed = workflow.withGraph(
        agents: other.agents,
        connections: other.connections,
      );

      expect(regraphed.id, workflow.id);
      expect(regraphed.name, workflow.name);
      expect(regraphed.signature, workflow.signature);
      expect(regraphed.agents, other.agents);
      expect(regraphed.connections, other.connections);
    }
  });

  test('test_agent_connection_equality_property_same_ends_equal', () {
    final Random random = seededRandom(9403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgentId from = WorkflowAgentId('a${random.nextInt(4)}');
      final WorkflowAgentId to = WorkflowAgentId('a${random.nextInt(4)}');
      final AgentConnection first = AgentConnection(from: from, to: to);
      final AgentConnection second = AgentConnection(from: from, to: to);
      final AgentConnection reversed = AgentConnection(from: to, to: from);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first == reversed, from == to);
    }
  });

  test('test_is_finished_property_only_without_pending_agents', () {
    final Random random = seededRandom(9404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final List<PendingAgent> pending = <PendingAgent>[
        for (final WorkflowAgent agent in workflow.agents)
          PendingAgent(name: agent.name, position: agent.position),
      ];
      final WorkflowDraftProgress progress = WorkflowDraftProgress(
        workflow: workflow,
        pendingAgents: pending,
        drafterKind: AgentKind.codex,
        drafterDeviceId: const DeviceId('device'),
      );

      expect(progress.isFinished, pending.isEmpty);
    }
  });

  test('test_skill_names_property_names_and_ids_round_trip', () {
    final Random random = seededRandom(9405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill skill = pickOne(random, gallerySkills);
      final List<String> names = describeSkillNames(
        skills: gallerySkills,
        skillIds: <SkillId>[skill.id],
      );

      expect(names, <String>[skill.name]);
      expect(
        findSkillIdByName(skills: gallerySkills, skillName: names.single),
        skill.id,
      );
    }
    expect(
      () => findSkillIdByName(skills: gallerySkills, skillName: 'missing'),
      throwsArgumentError,
    );
  });
}
