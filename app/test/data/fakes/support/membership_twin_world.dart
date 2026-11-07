import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/fakes/fake_workspace_contents.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/memory_workspace_choice_store.dart';
import '../../../support/workflow_repositories.dart';
import '../../node_backed/support/simulated_catalog_node.dart';
import '../../node_backed/support/simulated_node_replies.dart';
import 'catalog_twin_seeds.dart';
import 'device_inputs.dart';
import 'skill_inputs.dart';
import 'task_inputs.dart';
import 'workflow_inputs.dart';

const String simulatedOutsiderRefusal =
    'the app server answered 403: the device is not in that workspace';
const int _largestWorkspaceCount = 3;
const Duration _retryInterval = Duration(seconds: 30);
const DeviceId _twinDeviceId = DeviceId(simulatedDeviceId);

typedef MembershipTwinWorld = ({
  SimulatedCatalogNode simulated,
  CatalogTwinSeeds seeds,
  Set<WorkspaceId> memberWorkspaceIds,
  NodeBackedWorkspaceRepository nodeWorkspaces,
  NodeBackedProjectRepository nodeProjects,
  FakeWorkspaceRepository fakeWorkspaces,
  FakeProjectRepository fakeProjects,
  FakeDeviceRepository fakeDevices,
  FakeWorkspaceContents fakeContents,
});

Map<String, Object?>? _findListed(
  List<Map<String, Object?>> records,
  Object? identifier,
) {
  for (final Map<String, Object?> record in records) {
    if (record['id'] == identifier) {
      return record;
    }
  }
  return null;
}

final class _MembershipNode {
  _MembershipNode({required this.catalog, required this.memberWorkspaceIds});

  final SimulatedCatalogNode catalog;
  final Set<String> memberWorkspaceIds;

  String answer(String inputJson) {
    final SimulatedCommand command = jsonDecode(inputJson) as SimulatedCommand;
    final Object? workspaceId = _findTouchedWorkspaceId(command);
    if (workspaceId != null && !memberWorkspaceIds.contains(workspaceId)) {
      return encodeErrorReply(simulatedOutsiderRefusal);
    }
    return catalog.answer(inputJson);
  }

  Object? _findTouchedWorkspaceId(SimulatedCommand command) {
    final Object? name = command['command'];
    if (name == 'delete_workspace') {
      return _findListed(catalog.workspaces, command['workspace_id'])?['id'];
    }
    if (name == 'delete_project') {
      final Map<String, Object?>? project = _findListed(
        catalog.projects,
        command['project_id'],
      );
      return project?['workspace_id'];
    }
    return null;
  }
}

Set<WorkspaceId> _pickMembers(Random random, List<WorkspaceId> workspaceIds) {
  return <WorkspaceId>{
    for (final WorkspaceId workspaceId in workspaceIds)
      if (random.nextInt(3) != 0) workspaceId,
  };
}

FakeWorkspaceContents _buildContents({
  required CatalogTwinSeeds seeds,
  required FakeWorkspaceRepository workspaces,
  required FakeProjectRepository projects,
  required FakeTaskWork taskWork,
  required FakeDeviceRepository devices,
}) {
  final FakeWorkflowRepository workflows = buildWorkflowRepositoryIn(
    workflows: const <Workflow>[],
    changes: const <WorkflowChange>[],
    workspaceRepository: workspaces,
  );
  return FakeWorkspaceContents(
    projectRepository: projects,
    taskWork: taskWork,
    skillRepository: buildSkillRepositoryIn(seeds.skills, workspaces),
    ruleRepository: FakeRuleRepository(
      rules: seeds.rules,
      clock: FixedClock(galleryNow),
      workspaceRepository: workspaces,
    ),
    workflowRepository: workflows,
    deviceRepository: devices,
  );
}

Future<MembershipTwinWorld> buildMembershipTwinWorld(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final CatalogTwinSeeds seeds = seedCatalogTwins(
    random,
    simulated,
    1 + random.nextInt(_largestWorkspaceCount),
  );
  final Set<WorkspaceId> members = _pickMembers(random, seeds.workspaceIds);
  final _MembershipNode membership = _MembershipNode(
    catalog: simulated,
    memberWorkspaceIds: <String>{
      for (final WorkspaceId member in members) member.value,
    },
  );

  final NodeBackedWorkspaceRepository nodeWorkspaces =
      NodeBackedWorkspaceRepository(
        channel: buildSimulatedChannel(membership.answer),
        clock: FixedClock(galleryNow),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await nodeWorkspaces.load();
  final NodeBackedProjectRepository nodeProjects = NodeBackedProjectRepository(
    channel: buildSimulatedChannel(membership.answer),
    workspaceRepository: nodeWorkspaces,
  );
  await nodeProjects.load();

  final FakeWorkspaceRepository fakeWorkspaces = FakeWorkspaceRepository(
    workspaces: nodeWorkspaces.listWorkspaces(),
    currentWorkspaceId: nodeWorkspaces.currentWorkspace().id,
    appServerStatus: nodeWorkspaces.findAppServerStatus(),
    appServerGroup: nodeWorkspaces.findAppServerGroup(),
    currentDeviceId: _twinDeviceId,
    clock: FixedClock(galleryNow),
  );
  final FakeTaskRepository fakeTasks = buildTaskRepository(
    tasks: seeds.tasks,
    runs: seeds.runs,
    workflows: buildGalleryWorkflowRepository(),
  );
  final FakeTaskWork taskWork = FakeTaskWork(taskRepository: fakeTasks);
  final FakeProjectRepository fakeProjects = FakeProjectRepository(
    projects: seeds.projects,
    taskWork: taskWork,
  );
  final Device thisDevice = randomDeviceWithId(
    random,
    _twinDeviceId,
    isRevoked: false,
  ).withWorkspaces(members.toList());
  final FakeDeviceRepository fakeDevices = FakeDeviceRepository(
    devices: <Device>[thisDevice],
    currentDeviceId: _twinDeviceId,
    peerAddressProblem: null,
    gitlessFolderPaths: const <String>{},
  );
  fakeProjects.linkDevices(fakeDevices);
  final FakeWorkspaceContents fakeContents = _buildContents(
    seeds: seeds,
    workspaces: fakeWorkspaces,
    projects: fakeProjects,
    taskWork: taskWork,
    devices: fakeDevices,
  );
  fakeWorkspaces.linkContents(fakeContents);

  return (
    simulated: simulated,
    seeds: seeds,
    memberWorkspaceIds: members,
    nodeWorkspaces: nodeWorkspaces,
    nodeProjects: nodeProjects,
    fakeWorkspaces: fakeWorkspaces,
    fakeProjects: fakeProjects,
    fakeDevices: fakeDevices,
    fakeContents: fakeContents,
  );
}

List<String> listTwinWorkspaceIds(MembershipTwinWorld world) {
  return <String>[
    for (final Workspace workspace in world.nodeWorkspaces.listWorkspaces())
      workspace.id.value,
  ];
}

List<String> listFakeProjectIds(MembershipTwinWorld world) {
  return <String>[
    for (final Workspace workspace in world.fakeWorkspaces.listWorkspaces())
      for (final Project project in world.fakeProjects.listProjects(
        workspace.id,
      ))
        project.id.value,
  ];
}

List<String> listSimulatedProjectIds(MembershipTwinWorld world) {
  return <String>[
    for (final Map<String, Object?> project in world.simulated.projects)
      project['id']! as String,
  ];
}

Future<void> closeMembershipTwinWorld(MembershipTwinWorld world) async {
  await pumpEventQueue();
  world.nodeProjects.dispose();
}
