import 'support/reply_race_properties.dart';
import 'support/workflow_reply_race.dart';
import 'support/workflow_reply_race_steps.dart';

typedef _WorkflowStep = ReplyRaceStep<WorkflowReplyRace>;
typedef _WorkflowCase = ReplyRaceCase<WorkflowReplyRace>;

const List<_WorkflowStep> _elsewhereSteps = <_WorkflowStep>[
  addWorkflowElsewhere,
  renameWorkflowElsewhere,
  deleteWorkflowElsewhere,
];

const List<_WorkflowStep> _everyLocalStep = <_WorkflowStep>[
  createRaceWorkflow,
  saveRaceWorkflow,
  signRaceWorkflow,
  discardRaceChange,
  deleteRaceWorkflow,
  draftRaceWorkflow,
  changeRaceWorkflow,
  fillRaceAgentSettings,
];

const List<_WorkflowCase> _raceCases = <_WorkflowCase>[
  _WorkflowCase(
    testedName: 'node_backed_workflow_repository_create_workflow',
    seed: 81301,
    localSteps: <_WorkflowStep>[createRaceWorkflow],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkflowCase(
    testedName: 'node_backed_workflow_repository_save_workflow',
    seed: 81311,
    localSteps: <_WorkflowStep>[saveRaceWorkflow],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkflowCase(
    testedName: 'node_backed_workflow_repository_sign_workflow',
    seed: 81321,
    localSteps: <_WorkflowStep>[signRaceWorkflow, saveRaceWorkflow],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkflowCase(
    testedName: 'node_backed_workflow_repository_discard_change',
    seed: 81331,
    localSteps: <_WorkflowStep>[discardRaceChange, saveRaceWorkflow],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkflowCase(
    testedName: 'node_backed_workflow_repository_delete_workflow',
    seed: 81341,
    localSteps: <_WorkflowStep>[deleteRaceWorkflow, createRaceWorkflow],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkflowCase(
    testedName: 'node_backed_workflow_repository_draft_workflow',
    seed: 81351,
    localSteps: <_WorkflowStep>[draftRaceWorkflow],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkflowCase(
    testedName: 'node_backed_workflow_repository_change_workflow',
    seed: 81361,
    localSteps: <_WorkflowStep>[changeRaceWorkflow],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkflowCase(
    testedName: 'node_backed_workflow_repository_fill_agent_settings',
    seed: 81371,
    localSteps: <_WorkflowStep>[fillRaceAgentSettings],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkflowCase(
    testedName: 'node_backed_workflow_repository_store_view',
    seed: 81381,
    localSteps: _everyLocalStep,
    elsewhereSteps: _elsewhereSteps,
  ),
];

void main() {
  for (final _WorkflowCase raceCase in _raceCases) {
    registerReplyRaceProperties(
      openRace: openWorkflowReplyRace,
      raceCase: raceCase,
    );
  }
}
