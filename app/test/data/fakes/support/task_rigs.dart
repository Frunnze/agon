import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../../support/workflow_repositories.dart';
import 'task_inputs.dart';

typedef TaskRig = ({
  FakeTaskRepository repository,
  FakeWorkflowRepository flows,
});

const Set<RunStatus> activeRunStatuses = <RunStatus>{
  RunStatus.queued,
  RunStatus.running,
  RunStatus.waitingForApproval,
};

const Set<RunStatus> stoppedRunStatuses = <RunStatus>{
  RunStatus.failed,
  RunStatus.cancelled,
};

TaskRig buildTaskRig(TaskSeed seed) {
  final FakeWorkflowRepository flows = buildGalleryWorkflowRepository();
  final FakeTaskRepository repository = buildTaskRepository(
    tasks: seed.tasks,
    runs: seed.runs,
    workflows: flows,
  );
  return (repository: repository, flows: flows);
}

List<Task> listBusyTasks(FakeTaskRepository repository) {
  return <Task>[
    for (final Task task in repository.listTasksAndJobs())
      if (repository.listRuns(task.id).any(isRunActive)) task,
  ];
}

List<Task> listIdleTasks(FakeTaskRepository repository) {
  final List<Task> busy = listBusyTasks(repository);
  return <Task>[
    for (final Task task in repository.listTasksAndJobs())
      if (!busy.contains(task)) task,
  ];
}

List<Task> listStartableTasks(TaskRig rig) {
  return <Task>[
    for (final Task task in listIdleTasks(rig.repository))
      if (canStartDoer(rig.flows, task.doer)) task,
  ];
}

List<Run> listRunsWithStatus(
  FakeTaskRepository repository,
  Set<RunStatus> statuses,
) {
  return <Run>[
    for (final Task task in repository.listTasksAndJobs())
      for (final Run run in repository.listRuns(task.id))
        if (statuses.contains(run.status)) run,
  ];
}

List<String> describeTaskRepository(FakeTaskRepository repository) {
  return <String>[
    ...describeTasks(repository.listTasksAndJobs()),
    for (final Task task in repository.listTasksAndJobs())
      ...describeRuns(repository.listRuns(task.id)),
  ];
}
