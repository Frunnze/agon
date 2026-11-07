import 'support/reply_race_properties.dart';
import 'support/workspace_reply_race.dart';
import 'support/workspace_reply_race_steps.dart';

typedef _WorkspaceStep = ReplyRaceStep<WorkspaceReplyRace>;
typedef _WorkspaceCase = ReplyRaceCase<WorkspaceReplyRace>;

const List<_WorkspaceStep> _elsewhereSteps = <_WorkspaceStep>[
  addWorkspaceElsewhere,
  editWorkspaceElsewhere,
  deleteWorkspaceElsewhere,
  changeServerGroupElsewhere,
  flipServerReachabilityElsewhere,
];

const List<_WorkspaceStep> _workspaceEdits = <_WorkspaceStep>[
  createRaceWorkspace,
  saveRaceProtectedFiles,
  resetRaceProtectedFiles,
  changeRaceApprovalPolicy,
  deleteRaceWorkspace,
];

const List<_WorkspaceStep> _backupChanges = <_WorkspaceStep>[
  startRaceServerBackup,
  stopRaceServerBackup,
];

const List<_WorkspaceCase> _raceCases = <_WorkspaceCase>[
  _WorkspaceCase(
    testedName: 'node_backed_workspace_repository_create_workspace',
    seed: 81201,
    localSteps: <_WorkspaceStep>[createRaceWorkspace],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkspaceCase(
    testedName: 'node_backed_workspace_repository_save_protected_files',
    seed: 81211,
    localSteps: <_WorkspaceStep>[saveRaceProtectedFiles],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkspaceCase(
    testedName: 'node_backed_workspace_repository_reset_protected_files',
    seed: 81221,
    localSteps: <_WorkspaceStep>[
      resetRaceProtectedFiles,
      saveRaceProtectedFiles,
    ],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkspaceCase(
    testedName: 'node_backed_workspace_repository_change_approval_policy',
    seed: 81231,
    localSteps: <_WorkspaceStep>[changeRaceApprovalPolicy],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkspaceCase(
    testedName: 'node_backed_workspace_repository_delete_workspace',
    seed: 81241,
    localSteps: <_WorkspaceStep>[deleteRaceWorkspace, createRaceWorkspace],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkspaceCase(
    testedName: 'node_backed_workspace_repository_store_workspace_from_node',
    seed: 81251,
    localSteps: _workspaceEdits,
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkspaceCase(
    testedName: 'node_backed_workspace_repository_start_server_backup',
    seed: 81261,
    localSteps: <_WorkspaceStep>[startRaceServerBackup, stopRaceServerBackup],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkspaceCase(
    testedName: 'node_backed_workspace_repository_stop_server_backup',
    seed: 81271,
    localSteps: <_WorkspaceStep>[stopRaceServerBackup, startRaceServerBackup],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkspaceCase(
    testedName: 'node_backed_workspace_repository_change_server_backup',
    seed: 81281,
    localSteps: <_WorkspaceStep>[..._backupChanges, ..._workspaceEdits],
    elsewhereSteps: _elsewhereSteps,
  ),
  _WorkspaceCase(
    testedName: 'node_backed_workspace_repository_retry_app_server',
    seed: 81291,
    localSteps: <_WorkspaceStep>[retryRaceAppServer],
    elsewhereSteps: <_WorkspaceStep>[flipServerReachabilityElsewhere],
  ),
];

void main() {
  for (final _WorkspaceCase raceCase in _raceCases) {
    registerReplyRaceProperties(
      openRace: openWorkspaceReplyRace,
      raceCase: raceCase,
    );
  }
}
