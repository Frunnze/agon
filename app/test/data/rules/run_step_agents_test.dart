import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_step_agents.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

void main() {
  test('test_find_run_step_agent_property_finds_only_kept_agents', () {
    final Random random = seededRandom(7312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunStep step = pickOne(random, pickOne(random, galleryRuns).steps);
      final Workflow? workflow = random.nextBool()
          ? null
          : keepRandomAgents(random, pickOne(random, galleryWorkflows));

      final WorkflowAgent? found = findRunStepAgent(
        step: step,
        workflow: workflow,
      );

      final WorkflowAgentId? agentId = step.agentId;
      final bool isKept =
          workflow != null &&
          agentId != null &&
          workflow.agents.any((WorkflowAgent agent) => agent.id == agentId);
      expect(found != null, isKept);
      if (found != null) {
        expect(found.id, agentId);
      }
    }
  });
}
