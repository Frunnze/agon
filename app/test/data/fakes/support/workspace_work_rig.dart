import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../../bridge/support/random_work_json.dart';
import '../../../support/random_inputs.dart';
import '../../../support/sample_records.dart' show randomJobSchedule;
import '../../node_backed/support/node_backed_harness.dart';
import '../../node_backed/support/simulated_workspace_work_node.dart';
import 'workflow_inputs.dart';
import 'workspace_inputs.dart';

const ProjectId missingWorkProjectId = ProjectId('project-never-made');
const int _largestProjectCount = 5;
const int _largestSeededTaskCount = 7;
const Duration _livePollInterval = Duration(hours: 1);
final DateTime workRigMoment = DateTime.utc(2026, 10, 31, 9);

typedef WorkspaceWorkRig = ({
  FakeWorkspaceRepository workspaces,
  List<WorkspaceId> workspaceIds,
  List<Project> projects,
  FakeProjectRepository fakeProjects,
  FakeTaskRepository fakeTasks,
  FakeJobRepository fakeJobs,
  SimulatedWorkspaceWorkNode simulated,
  NodeBackedTaskRepository nodeTasks,
  NodeBackedJobRepository nodeJobs,
  Map<TaskId, TaskId> nodeIdOfFakeId,
});

bool isWorkRefusal(Object error) {
  return error is StateError || error is RecordNotFound;
}

Object? _copyWire(Object? json) => jsonDecode(jsonEncode(json));

List<Project> _randomProjects(Random random, List<WorkspaceId> workspaceIds) {
  final int count = 1 + random.nextInt(_largestProjectCount);
  return <Project>[
    for (int index = 0; index < count; index += 1)
      Project(
        id: ProjectId('work-project-$index'),
        workspaceId: pickOne(random, workspaceIds),
        name: 'work-project-$index',
        repositories: const <Repository>[],
        approvalPolicy: null,
      ),
  ];
}

ProjectId pickWorkProjectId(Random random, List<Project> projects) {
  if (random.nextInt(6) == 0) {
    return missingWorkProjectId;
  }
  return pickOne(random, projects).id;
}

String randomWorkTitle(Random random) => 'work ${randomText(random)}';

Map<String, Object?> _randomWireTask(
  Random random,
  int index,
  List<Project> projects,
) {
  final Map<String, Object?> wire = randomTaskJson(random);
  wire['id'] = 'seeded-work-$index';
  wire['title'] = randomWorkTitle(random);
  wire['project_id'] = pickWorkProjectId(random, projects).value;
  wire['doer'] = <String, Object?>{'kind': 'one_agent', 'agent': 'codex'};
  wire['status'] = 'to_do';
  return wire;
}

List<Task> _seedWork(
  Random random,
  SimulatedWorkspaceWorkNode simulated,
  List<Project> projects,
) {
  final int count = random.nextInt(_largestSeededTaskCount + 1);
  final List<Task> tasks = <Task>[];
  for (int index = 0; index < count; index += 1) {
    final Map<String, Object?> wire = _randomWireTask(random, index, projects);
    final Object? copied = _copyWire(wire);
    simulated.work.tasks[wire['id']! as String] =
        copied! as Map<String, Object?>;
    tasks.add(mapTaskFromNode(node.Task.fromJson(_copyWire(wire))));
  }
  return tasks;
}

FakeTaskRepository _buildFakeTasks(
  List<Task> tasks,
  FakeWorkspaceRepository workspaces,
) {
  return FakeTaskRepository(
    tasks: tasks,
    runs: const <Run>[],
    clock: FixedClock(workRigMoment),
    currentDeviceId: const DeviceId(simulatedWorkDeviceId),
    workflowRepository: buildWorkflowRepositoryIn(
      workflows: const <Workflow>[],
      changes: const <WorkflowChange>[],
      workspaceRepository: workspaces,
    ),
  );
}

Future<WorkspaceWorkRig> buildWorkspaceWorkRig(Random random) async {
  final SeededWorkspaces seeded = seedRandomWorkspaces(random);
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[
    for (final Workspace workspace in seeded.workspaces) workspace.id,
  ];
  final List<Project> projects = _randomProjects(random, workspaceIds);
  final SimulatedWorkspaceWorkNode simulated = SimulatedWorkspaceWorkNode(
    projectWorkspaces: <String, String>{
      for (final Project project in projects)
        project.id.value: project.workspaceId.value,
    },
  );
  final List<Task> seededTasks = _seedWork(random, simulated, projects);

  final FakeTaskRepository fakeTasks = _buildFakeTasks(
    seededTasks,
    seeded.repository,
  );
  final FakeProjectRepository fakeProjects = FakeProjectRepository(
    projects: projects,
    taskWork: FakeTaskWork(taskRepository: fakeTasks),
  );
  fakeTasks.linkPlaces((
    workspaceRepository: seeded.repository,
    projectRepository: fakeProjects,
  ));

  final NodeBackedJobRepository nodeJobs = NodeBackedJobRepository(
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: seeded.repository,
    clock: FixedClock(workRigMoment),
  );
  final NodeBackedTaskRepository nodeTasks = NodeBackedTaskRepository(
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: seeded.repository,
    livePollInterval: _livePollInterval,
    jobRepository: nodeJobs,
    clock: FixedClock(workRigMoment),
  );
  await nodeJobs.load();
  await nodeTasks.load();

  return (
    workspaces: seeded.repository,
    workspaceIds: workspaceIds,
    projects: projects,
    fakeProjects: fakeProjects,
    fakeTasks: fakeTasks,
    fakeJobs: FakeJobRepository(
      taskRepository: fakeTasks,
      clock: FixedClock(workRigMoment),
    ),
    simulated: simulated,
    nodeTasks: nodeTasks,
    nodeJobs: nodeJobs,
    nodeIdOfFakeId: <TaskId, TaskId>{
      for (final Task task in seededTasks) task.id: task.id,
    },
  );
}

TaskDraft randomWorkDraft(Random random, List<Project> projects) {
  final TaskDraft base = randomTaskDraft(random);
  return TaskDraft(
    title: randomWorkTitle(random),
    details: base.details,
    projectId: pickWorkProjectId(random, projects),
    doer: const OneAgentDoer(AgentKind.codex),
    runsOn: base.runsOn,
    agentPlace: base.agentPlace,
    skills: base.skills,
    usesAutomaticSkills: base.usesAutomaticSkills,
    approvalPolicy: base.approvalPolicy,
  );
}

JobDraft randomWorkJobDraft(Random random, List<Project> projects) {
  return JobDraft(
    task: randomWorkDraft(random, projects),
    schedule: randomJobSchedule(random),
  );
}

TaskId pickWorkTaskId(Random random, WorkspaceWorkRig rig) {
  final List<TaskId> known = rig.nodeIdOfFakeId.keys.toList();
  if (known.isEmpty || random.nextInt(6) == 0) {
    return TaskId('missing-${randomText(random)}');
  }
  return pickOne(random, known);
}

TaskId findNodeIdOf(WorkspaceWorkRig rig, TaskId fakeId) {
  return rig.nodeIdOfFakeId[fakeId] ?? fakeId;
}

Future<void> switchWorkRigWorkspace(
  Random random,
  WorkspaceWorkRig rig,
) async {
  await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
  await rig.nodeJobs.load();
  await rig.nodeTasks.load();
}

Future<void> closeWorkspaceWorkRig(WorkspaceWorkRig rig) async {
  await pumpEventQueue();
  rig.nodeTasks.dispose();
  rig.nodeJobs.dispose();
  rig.fakeTasks.dispose();
}
