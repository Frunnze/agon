import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../../bridge/support/node_wire_names.dart';
import '../../../support/random_inputs.dart';
import '../../../support/sample_records.dart';
import '../../../support/workflow_repositories.dart';
import 'task_inputs.dart';

const List<ProjectId> workProjectIds = <ProjectId>[
  ProjectId('work-project-0'),
  ProjectId('work-project-1'),
  ProjectId('work-project-2'),
  ProjectId('work-project-3'),
];
const List<WorkflowId> workWorkflowIds = <WorkflowId>[
  WorkflowId('work-workflow-0'),
  WorkflowId('work-workflow-1'),
  WorkflowId('work-workflow-2'),
];
const Set<RunStatus> serverFinishedRunStatuses = <RunStatus>{
  RunStatus.done,
  RunStatus.failed,
  RunStatus.cancelled,
};
const int _largestTaskCount = 7;
const int _largestRunsPerTask = 2;

typedef ProjectWorkSeed = ({List<Task> tasks, List<Run> runs});

TaskDoer _randomDoer(Random random) {
  if (random.nextBool()) {
    return OneAgentDoer(pickOne(random, AgentKind.values));
  }
  return WorkflowDoer(pickOne(random, workWorkflowIds));
}

Task _randomProjectTask(Random random, int index) {
  final TaskDraft base = randomTaskDraft(random);
  final TaskDraft draft = TaskDraft(
    title: base.title,
    details: base.details,
    projectId: pickOne(random, workProjectIds),
    doer: _randomDoer(random),
    runsOn: base.runsOn,
    agentPlace: base.agentPlace,
    skills: base.skills,
    usesAutomaticSkills: base.usesAutomaticSkills,
    approvalPolicy: base.approvalPolicy,
  );
  return Task.fromDraft(
    id: TaskId('work-task-$index'),
    draft: draft,
    schedule: random.nextBool() ? randomJobSchedule(random) : null,
    status: TaskStatus.toDo,
    createdAt: randomUtcMoment(random),
  );
}

ProjectWorkSeed randomProjectWork(Random random) {
  final int taskCount = random.nextInt(_largestTaskCount + 1);
  final List<Task> tasks = <Task>[];
  final List<Run> runs = <Run>[];
  for (int index = 0; index < taskCount; index += 1) {
    final Task task = _randomProjectTask(random, index);
    tasks.add(task);
    final int runCount = random.nextInt(_largestRunsPerTask + 1);
    for (int number = 1; number <= runCount; number += 1) {
      runs.add(
        buildSeededRun(
          random,
          runId: 'work-run-$index-$number',
          taskId: task.id,
          number: number,
          status: pickOne(random, nodeRunStatuses),
        ),
      );
    }
  }
  return (tasks: tasks, runs: runs);
}

FakeTaskRepository buildProjectWorkRepository(ProjectWorkSeed seed) {
  return buildTaskRepository(
    tasks: seed.tasks,
    runs: seed.runs,
    workflows: buildGalleryWorkflowRepository(),
  );
}

bool isRunningLikeServer(ProjectWorkSeed seed, Set<ProjectId> projectIds) {
  for (final Run run in seed.runs) {
    final Task task = seed.tasks.firstWhere(
      (Task candidate) => candidate.id == run.taskId,
    );
    final bool isUnfinished = !serverFinishedRunStatuses.contains(run.status);
    if (projectIds.contains(task.projectId) && isUnfinished) {
      return true;
    }
  }
  return false;
}

Set<ProjectId> randomProjectSubset(Random random) {
  final Set<ProjectId> picked = <ProjectId>{};
  for (final ProjectId projectId in workProjectIds) {
    if (random.nextBool()) {
      picked.add(projectId);
    }
  }
  return picked;
}

List<TaskId> listWorkIds(FakeTaskRepository repository) {
  return <TaskId>[
    for (final Task task in repository.listTasksAndJobs()) task.id,
  ];
}
