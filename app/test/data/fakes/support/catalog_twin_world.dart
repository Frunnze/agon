import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/fakes/fake_workspace_contents.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../support/fake_task_work_links.dart';
import '../../../support/memory_workspace_choice_store.dart';
import '../../../support/workflow_repositories.dart';
import '../../node_backed/support/simulated_catalog_node.dart';
import 'catalog_twin_seeds.dart';
import 'device_inputs.dart';
import 'skill_inputs.dart';
import 'task_inputs.dart';
import 'workflow_inputs.dart';

const int _largestWorkspaceCount = 3;
const Duration _retryInterval = Duration(seconds: 30);
const DeviceId _twinDeviceId = DeviceId(simulatedDeviceId);

typedef CatalogTwinWorld = ({
  SimulatedCatalogNode simulated,
  CatalogTwinSeeds seeds,
  NodeBackedWorkspaceRepository nodeWorkspaces,
  NodeBackedProjectRepository nodeProjects,
  NodeBackedSkillRepository nodeSkills,
  NodeBackedRuleRepository nodeRules,
  FakeWorkspaceRepository fakeWorkspaces,
  FakeProjectRepository fakeProjects,
  FakeSkillRepository fakeSkills,
  FakeRuleRepository fakeRules,
  FakeTaskRepository fakeTasks,
  FakeDeviceRepository fakeDevices,
});

typedef _NodeRepositories = ({
  NodeBackedWorkspaceRepository workspaces,
  NodeBackedProjectRepository projects,
  NodeBackedSkillRepository skills,
  NodeBackedRuleRepository rules,
});

Future<_NodeRepositories> _openNode(SimulatedCatalogNode simulated) async {
  final NodeBackedWorkspaceRepository workspaces =
      NodeBackedWorkspaceRepository(
        channel: simulated.channel,
        clock: FixedClock(galleryNow),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await workspaces.load();
  final NodeBackedProjectRepository projects = NodeBackedProjectRepository(
    channel: simulated.channel,
    workspaceRepository: workspaces,
  );
  final NodeBackedSkillRepository skills = NodeBackedSkillRepository(
    channel: simulated.channel,
    workspaceRepository: workspaces,
  );
  final NodeBackedRuleRepository rules = NodeBackedRuleRepository(
    channel: simulated.channel,
    workspaceRepository: workspaces,
  );
  await projects.load();
  await skills.load();
  await rules.load();
  return (
    workspaces: workspaces,
    projects: projects,
    skills: skills,
    rules: rules,
  );
}

FakeWorkspaceRepository _buildFakeWorkspaces(_NodeRepositories opened) {
  return FakeWorkspaceRepository(
    workspaces: opened.workspaces.listWorkspaces(),
    currentWorkspaceId: opened.workspaces.currentWorkspace().id,
    appServerStatus: opened.workspaces.findAppServerStatus(),
    appServerGroup: opened.workspaces.findAppServerGroup(),
    currentDeviceId: _twinDeviceId,
    clock: FixedClock(galleryNow),
  );
}

FakeDeviceRepository _buildFakeDevices(Random random, CatalogTwinSeeds seeds) {
  final Device thisDevice = randomDeviceWithId(
    random,
    _twinDeviceId,
    isRevoked: false,
  ).withWorkspaces(seeds.workspaceIds);
  return FakeDeviceRepository(
    devices: <Device>[thisDevice],
    currentDeviceId: _twinDeviceId,
    peerAddressProblem: null,
    gitlessFolderPaths: const <String>{},
  );
}

FakeWorkflowRepository _buildFakeWorkflows(
  FakeWorkspaceRepository workspaces,
  FakeTaskWork taskWork,
) {
  final FakeWorkflowRepository workflows = buildWorkflowRepositoryIn(
    workflows: const <Workflow>[],
    changes: const <WorkflowChange>[],
    workspaceRepository: workspaces,
  );
  workflows.linkWork(
    taskWork: taskWork,
    approvalRepository: FakeApprovalRepository(
      approvals: const <ApprovalRequest>[],
      clock: FixedClock(galleryNow),
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
  );
  return workflows;
}

Future<CatalogTwinWorld> buildCatalogTwinWorld(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final CatalogTwinSeeds seeds = seedCatalogTwins(
    random,
    simulated,
    1 + random.nextInt(_largestWorkspaceCount),
  );
  final _NodeRepositories opened = await _openNode(simulated);
  final FakeWorkspaceRepository fakeWorkspaces = _buildFakeWorkspaces(opened);
  final FakeTaskRepository fakeTasks = buildTaskRepository(
    tasks: seeds.tasks,
    runs: seeds.runs,
    workflows: buildGalleryWorkflowRepository(),
  );
  final FakeTaskWork taskWork = buildTaskWorkOver(fakeTasks);
  final FakeProjectRepository fakeProjects = FakeProjectRepository(
    projects: seeds.projects,
    taskWork: taskWork,
  );
  final FakeSkillRepository fakeSkills = buildSkillRepositoryIn(
    seeds.skills,
    fakeWorkspaces,
  );
  fakeSkills.linkTasks(fakeTasks);
  final FakeRuleRepository fakeRules = FakeRuleRepository(
    rules: seeds.rules,
    clock: FixedClock(galleryNow),
    workspaceRepository: fakeWorkspaces,
  );
  fakeProjects.linkLibrary(
    skillRepository: fakeSkills,
    ruleRepository: fakeRules,
  );
  final FakeDeviceRepository fakeDevices = _buildFakeDevices(random, seeds);
  fakeWorkspaces.linkContents(
    FakeWorkspaceContents(
      projectRepository: fakeProjects,
      taskWork: taskWork,
      skillRepository: fakeSkills,
      ruleRepository: fakeRules,
      workflowRepository: _buildFakeWorkflows(fakeWorkspaces, taskWork),
      deviceRepository: fakeDevices,
    ),
  );
  return (
    simulated: simulated,
    seeds: seeds,
    nodeWorkspaces: opened.workspaces,
    nodeProjects: opened.projects,
    nodeSkills: opened.skills,
    nodeRules: opened.rules,
    fakeWorkspaces: fakeWorkspaces,
    fakeProjects: fakeProjects,
    fakeSkills: fakeSkills,
    fakeRules: fakeRules,
    fakeTasks: fakeTasks,
    fakeDevices: fakeDevices,
  );
}

void closeCatalogTwinWorld(CatalogTwinWorld world) {
  world.nodeSkills.dispose();
  world.nodeRules.dispose();
  world.nodeProjects.dispose();
  world.fakeSkills.dispose();
  world.fakeRules.dispose();
}
