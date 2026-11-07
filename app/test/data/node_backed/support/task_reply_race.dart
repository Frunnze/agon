import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';

import '../../../bridge/support/random_work_json.dart';
import '../../../support/random_inputs.dart';
import '../../fakes/support/workspace_inputs.dart';
import 'node_backed_harness.dart';
import 'out_of_order_replies.dart';
import 'simulated_work_node.dart';
import 'simulated_workspace_work_node.dart';

const int _workspaceCount = 3;
const int _projectCount = 4;
const int _largestSeededTaskCount = 5;
const Duration _livePollInterval = Duration(hours: 1);
const Set<String> _taskChangeCommands = <String>{
  'create_task',
  'update_task',
  'delete_task',
  'start_task',
  'cancel_run',
  'retry_run',
};
const node.AreaChanged _tasksChanged = node.AreaChanged(
  area: node.ChangeArea.tasks,
);
final DateTime _raceMoment = DateTime.utc(2026, 11, 7);

typedef TaskReplyRace = ({
  SimulatedWorkspaceWorkNode node,
  OutOfOrderReplyTransport transport,
  AnnouncingNodeAnswer announcements,
  FakeWorkspaceRepository workspaces,
  List<Project> projects,
  NodeBackedJobRepository jobs,
  NodeBackedTaskRepository tasks,
  PendingRaceWork pendingWork,
});

List<Project> _buildRaceProjects(Random random, List<Workspace> workspaces) {
  return <Project>[
    for (int index = 0; index < _projectCount; index += 1)
      Project(
        id: ProjectId('race-project-$index'),
        workspaceId: pickOne(random, workspaces).id,
        name: 'race-project-$index',
        repositories: const <Repository>[],
        approvalPolicy: null,
      ),
  ];
}

void _seedRaceTasks(
  Random random,
  SimulatedWorkspaceWorkNode simulated,
  List<Project> projects,
) {
  final int count = random.nextInt(_largestSeededTaskCount + 1);
  for (int index = 0; index < count; index += 1) {
    final WireRecord task = randomTaskJson(random);
    task['id'] = 'seeded-race-task-$index';
    task['project_id'] = pickOne(random, projects).id.value;
    task['schedule'] = null;
    task['status'] = 'to_do';
    simulated.work.tasks[task['id']! as String] = task;
  }
}

NodeBackedTaskRepository buildRaceTaskRepository({
  required NodeCommandChannel channel,
  required FakeWorkspaceRepository workspaces,
  required NodeBackedJobRepository jobs,
}) {
  return NodeBackedTaskRepository(
    channel: channel,
    workspaceRepository: workspaces,
    livePollInterval: _livePollInterval,
    jobRepository: jobs,
    clock: FixedClock(_raceMoment),
  );
}

Future<TaskReplyRace> openTaskReplyRace(Random random) async {
  final List<Workspace> workspaceList = <Workspace>[
    for (int index = 0; index < _workspaceCount; index += 1)
      buildSampleWorkspace(random, index),
  ];
  final FakeWorkspaceRepository workspaces = buildWorkspaceRepository(
    workspaces: workspaceList,
    currentWorkspaceId: pickOne(random, workspaceList).id,
    appServerGroup: randomAppServerGroup(random),
  );
  final List<Project> projects = _buildRaceProjects(random, workspaceList);
  final SimulatedWorkspaceWorkNode simulated = SimulatedWorkspaceWorkNode(
    projectWorkspaces: <String, String>{
      for (final Project project in projects)
        project.id.value: project.workspaceId.value,
    },
  );
  _seedRaceTasks(random, simulated, projects);

  final AnnouncingNodeAnswer announcements = AnnouncingNodeAnswer(
    answer: simulated.answer,
    changeCommands: _taskChangeCommands,
  );
  final OutOfOrderReplyTransport transport = OutOfOrderReplyTransport(
    answer: announcements.answerAndAnnounce,
    random: random,
  );
  final NodeBackedJobRepository jobs = NodeBackedJobRepository(
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: workspaces,
    clock: FixedClock(_raceMoment),
  );
  final NodeBackedTaskRepository tasks = buildRaceTaskRepository(
    channel: NodeCommandChannel(transport: transport),
    workspaces: workspaces,
    jobs: jobs,
  );
  await tasks.load();
  transport.isHoldingReplies = true;
  return (
    node: simulated,
    transport: transport,
    announcements: announcements,
    workspaces: workspaces,
    projects: projects,
    jobs: jobs,
    tasks: tasks,
    pendingWork: PendingRaceWork(),
  );
}

void announceTaskChange(TaskReplyRace race, node.ChangeTopic topic) {
  race.pendingWork.start(race.tasks.applyChange(topic));
}

void deliverWaitingTaskAnnouncement(TaskReplyRace race) {
  if (race.announcements.waitingAnnouncements == 0) {
    return;
  }
  race.announcements.takeAnnouncement();
  announceTaskChange(race, _tasksChanged);
}

void addTaskElsewhere(Random random, TaskReplyRace race) {
  final String taskId = race.node.work.addTaskFromElsewhere(random);
  final WireRecord task = race.node.work.tasks[taskId]!;
  task['project_id'] = pickOne(random, race.projects).id.value;
  task['schedule'] = null;
  announceTaskChange(race, _tasksChanged);
}

void deleteTaskElsewhere(Random random, TaskReplyRace race) {
  if (race.node.work.tasks.isEmpty) {
    return;
  }
  final String taskId = pickOne(random, race.node.work.tasks.keys.toList());
  race.node.work.tasks.remove(taskId);
  race.node.work.runs.removeWhere(
    (String _, WireRecord run) => run['task_id'] == taskId,
  );
  announceTaskChange(race, _tasksChanged);
}

void changeRunElsewhere(Random random, TaskReplyRace race) {
  if (race.node.work.runs.isEmpty) {
    return;
  }
  final String runId = pickOne(random, race.node.work.runs.keys.toList());
  race.node.work.changeRunFromElsewhere(random, runId);
  announceTaskChange(race, node.RunChanged(runId: RunId(runId)));
}

void switchRaceWorkspace(Random random, TaskReplyRace race) {
  final Workspace chosen = pickOne(random, race.workspaces.listWorkspaces());
  race.pendingWork.start(race.workspaces.switchWorkspace(chosen.id));
}

TaskId? pickListedTaskId(Random random, TaskReplyRace race) {
  final List<Task> listed = race.tasks.listTasks();
  if (listed.isEmpty) {
    return null;
  }
  return pickOne(random, listed).id;
}

RunId? pickListedRunId(Random random, TaskReplyRace race) {
  final List<Run> runs = <Run>[
    for (final Task task in race.tasks.listTasks())
      ...race.tasks.listRuns(task.id),
  ];
  if (runs.isEmpty) {
    return null;
  }
  return pickOne(random, runs).id;
}

Future<void> _releaseEverything(TaskReplyRace race) {
  return releaseRepliesAndAnnouncements(
    transport: race.transport,
    announcements: race.announcements,
    deliverAnnouncement: () => announceTaskChange(race, _tasksChanged),
  );
}

List<String> describeTaskListing(TaskRepository tasks) {
  final List<String> described = <String>[];
  for (final Task task in tasks.listTasks()) {
    described.add(
      '${task.id.value} ${task.projectId.value} ${task.status.name} '
      '${task.title}',
    );
    for (final Run run in tasks.listRuns(task.id)) {
      described.add(
        '${task.id.value} run ${run.id.value} ${run.number} '
        '${run.status.name} ${run.chat.length}',
      );
    }
  }
  return described;
}

Future<List<String>> finishTaskReplyRace(TaskReplyRace race) async {
  await _releaseEverything(race);
  await race.pendingWork.finish();
  await _releaseEverything(race);
  return describeTaskListing(race.tasks);
}

Future<List<String>> reloadTaskListing(TaskReplyRace race) async {
  final NodeBackedTaskRepository reloaded = buildRaceTaskRepository(
    channel: buildSimulatedChannel(race.node.answer),
    workspaces: race.workspaces,
    jobs: race.jobs,
  );
  await reloaded.load();
  final List<String> listing = describeTaskListing(reloaded);
  reloaded.dispose();
  return listing;
}

void closeTaskReplyRace(TaskReplyRace race) {
  race.tasks.dispose();
  race.jobs.dispose();
}
