import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

import '../../../support/random_inputs.dart';
import 'simulated_workflow_views.dart';
import 'workflow_reply_race.dart';

const WorkflowId _unsavedWorkflowId = WorkflowId('unsaved');

Workflow? _pickListedWorkflow(Random random, WorkflowReplyRace race) {
  final List<Workflow> listed = race.workflows.listWorkflows();
  if (listed.isEmpty) {
    return null;
  }
  return pickOne(random, listed);
}

Workflow _buildUnsavedWorkflow(Random random) {
  final Workflow empty = Workflow(
    id: _unsavedWorkflowId,
    name: 'flow-${random.nextInt(1000)}',
    availability: randomRaceAvailability(random),
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
    signature: null,
  );
  return addAgent(empty, buildBlankAgent(empty));
}

Workflow _renameWorkflow(Random random, Workflow workflow) {
  return Workflow(
    id: workflow.id,
    name: 'renamed-${random.nextInt(1000)}',
    availability: randomRaceAvailability(random),
    agents: workflow.agents,
    connections: workflow.connections,
    signature: workflow.signature,
  );
}

void createRaceWorkflow(Random random, WorkflowReplyRace race) {
  final Workflow unsaved = _buildUnsavedWorkflow(random);
  race.pendingWork.start(race.workflows.createWorkflow(unsaved));
}

void saveRaceWorkflow(Random random, WorkflowReplyRace race) {
  final Workflow? listed = _pickListedWorkflow(random, race);
  if (listed == null) {
    return;
  }
  final Workflow renamed = _renameWorkflow(random, listed);
  race.pendingWork.start(race.workflows.saveWorkflow(renamed));
}

void signRaceWorkflow(Random random, WorkflowReplyRace race) {
  final Workflow? listed = _pickListedWorkflow(random, race);
  if (listed == null) {
    return;
  }
  race.pendingWork.start(race.workflows.signWorkflow(listed.id));
}

void discardRaceChange(Random random, WorkflowReplyRace race) {
  final Workflow? listed = _pickListedWorkflow(random, race);
  if (listed == null) {
    return;
  }
  race.pendingWork.start(race.workflows.discardChange(listed.id));
}

void deleteRaceWorkflow(Random random, WorkflowReplyRace race) {
  final Workflow? listed = _pickListedWorkflow(random, race);
  if (listed == null) {
    return;
  }
  race.pendingWork.start(race.workflows.deleteWorkflow(listed.id));
}

void draftRaceWorkflow(Random random, WorkflowReplyRace race) {
  final WorkflowDraft draft = WorkflowDraft(
    description: 'Draft ${random.nextInt(1000)} steps',
  );
  race.pendingWork.start(race.workflows.draftWorkflow(draft).last);
}

void changeRaceWorkflow(Random random, WorkflowReplyRace race) {
  final Workflow? listed = _pickListedWorkflow(random, race);
  if (listed == null) {
    return;
  }
  race.pendingWork.start(
    race.workflows.changeWorkflow(
      listed.id,
      'Add a step ${random.nextInt(1000)}',
      pickOne(random, AgentKind.values),
    ),
  );
}

void fillRaceAgentSettings(Random random, WorkflowReplyRace race) {
  final Workflow? listed = _pickListedWorkflow(random, race);
  if (listed == null || listed.agents.isEmpty) {
    return;
  }
  final WorkflowAgent agent = pickOne(random, listed.agents);
  race.pendingWork.start(
    race.workflows.fillAgentSettings(listed.id, agent.id),
  );
}

void addWorkflowElsewhere(Random random, WorkflowReplyRace race) {
  race.node.addWorkflowElsewhere();
  race.announceWorkflowChange();
}

void renameWorkflowElsewhere(Random random, WorkflowReplyRace race) {
  final List<SimulatedWorkflowView> views = race.node.workflows.views;
  if (views.isEmpty) {
    return;
  }
  final int position = random.nextInt(views.length);
  final SimulatedWorkflowView view = views[position];
  final Map<String, Object?> renamed = <String, Object?>{
    ...readSimulatedWorkflow(view),
    'name': 'elsewhere-renamed-${random.nextInt(1000)}',
  };
  views[position] = buildSimulatedWorkflowView(
    renamed,
    view['signature_state']! as String,
  );
  race.announceWorkflowChange();
}

void deleteWorkflowElsewhere(Random random, WorkflowReplyRace race) {
  final List<SimulatedWorkflowView> views = race.node.workflows.views;
  if (views.isEmpty) {
    return;
  }
  views.removeAt(random.nextInt(views.length));
  race.announceWorkflowChange();
}
