import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

void main() {
  test('test_describe_agent_name_problem_property_unique_slugs_only', () {
    final Random random = seededRandom(8901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent agent = pickOne(random, workflow.agents);
      final String name = random.nextBool()
          ? pickOne(random, workflow.agents).name
          : randomWordPhrase(random).replaceAll(' ', '-');
      final bool isTakenByOther = workflow.agents.any(
        (WorkflowAgent other) => other.id != agent.id && other.name == name,
      );
      final String? problem = describeAgentNameProblem(
        workflow: workflow,
        agent: agent,
        name: name,
      );

      if (describeNameProblem(name) != null) {
        expect(problem, describeNameProblem(name));
      } else if (isTakenByOther) {
        expect(problem, 'Another agent has this name');
      } else {
        expect(problem, isNull);
      }
    }
  });

  test('test_describe_signing_problem_property_blank_agents_block', () {
    final Random random = seededRandom(8902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final String? problem = describeSigningProblem(workflow);
      final bool hasBlank = workflow.agents.any(
        (WorkflowAgent agent) =>
            agent.kind == null || agent.task.trim().isEmpty,
      );

      if (workflow.agents.isEmpty) {
        expect(problem, 'Add at least one agent');
      } else if (hasBlank) {
        expect(problem, isNotNull);
      } else {
        expect(problem, isNull);
      }
    }
  });

  test('describe signing problem names the agent to fix', () {
    final Workflow pipeline = galleryWorkflows[2];
    final Workflow withBlank = addAgent(pipeline, buildBlankAgent(pipeline));

    expect(describeSigningProblem(pipeline), isNull);
    expect(describeSigningProblem(withBlank), 'Choose an agent for new-agent');
    expect(
      describeSigningProblem(
        replaceAgent(pipeline, pipeline.agents.first.copyWith(task: ' ')),
      ),
      'Write a task for plan',
    );
  });

  test('test_build_agent_kind_entries_property_placeholder_only_unset', () {
    for (final AgentKind? kind in <AgentKind?>[null, ...AgentKind.values]) {
      final List<AgentKindChoice> values = <AgentKindChoice>[
        for (final entry in buildAgentKindEntries(kind)) entry.value,
      ];

      expect(values, contains(AgentKindChoice(kind)));
      expect(values.contains(const AgentKindChoice(null)), kind == null);
      expect(values.length, AgentKind.values.length + (kind == null ? 1 : 0));
    }
  });
}
