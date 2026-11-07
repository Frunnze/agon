import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../../support/random_inputs.dart';
import 'workspace_work_rig.dart';

typedef HiddenWorkRig = ({WorkspaceWorkRig rig, Task hidden});

List<ProjectId> listCurrentWorkProjectIds(WorkspaceWorkRig rig) {
  final WorkspaceId current = rig.workspaces.currentWorkspace().id;
  return <ProjectId>[
    for (final Project project in rig.projects)
      if (project.workspaceId == current) project.id,
  ];
}

ProjectId? pickOutsideWorkProjectId(Random random, WorkspaceWorkRig rig) {
  final List<ProjectId> current = listCurrentWorkProjectIds(rig);
  final List<ProjectId> outside = <ProjectId>[
    for (final Project project in rig.projects)
      if (!current.contains(project.id)) project.id,
  ];
  if (outside.isEmpty) {
    return null;
  }
  return pickOne(random, outside);
}

TaskDraft randomWorkDraftIn(
  Random random,
  WorkspaceWorkRig rig,
  ProjectId projectId,
) {
  final TaskDraft draft = randomWorkDraft(random, rig.projects);
  return TaskDraft(
    title: draft.title,
    details: draft.details,
    projectId: projectId,
    doer: draft.doer,
    runsOn: draft.runsOn,
    agentPlace: draft.agentPlace,
    skills: draft.skills,
    usesAutomaticSkills: draft.usesAutomaticSkills,
    approvalPolicy: draft.approvalPolicy,
  );
}

List<Task> listHiddenWork(WorkspaceWorkRig rig) {
  final Set<TaskId> visible = <TaskId>{
    for (final Task task in rig.fakeTasks.listTasksAndJobsInCurrentWorkspace())
      task.id,
  };
  return <Task>[
    for (final Task task in rig.fakeTasks.listTasksAndJobs())
      if (!visible.contains(task.id)) task,
  ];
}

Future<HiddenWorkRig?> buildHiddenWorkRig(Random random) async {
  final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
  final List<Task> hidden = listHiddenWork(rig);
  if (hidden.isEmpty) {
    await closeWorkspaceWorkRig(rig);
    return null;
  }
  return (rig: rig, hidden: pickOne(random, hidden));
}
